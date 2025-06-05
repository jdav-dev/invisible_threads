defmodule InvisibleThreads.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias InvisibleThreads.Accounts.User
  alias InvisibleThreads.Postmark

  @session_validity_in_days 14
  @session_validity_in_seconds @session_validity_in_days * 24 * 60 * 60
  @token_salt "K7CMLqwn"

  @doc """
  Gets a single user.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  def get_user(id) do
    id
    |> user_file()
    |> File.read()
    |> case do
      {:ok, binary} -> :erlang.binary_to_term(binary)
      _error -> nil
    end
  end

  defp user_file(id) do
    Path.join(data_dir(), "#{id}.etf")
  end

  @doc false
  def data_dir do
    Application.get_env(:invisible_threads, :data_dir, Path.expand("../../data", __DIR__))
  end

  @doc """
  Updates a single user.

  ## Examples

      iex> update_user!(user_id, &struct!(&1, name: "new name"))
      %User{name: "new name"}

  """
  def update_user!(user_id, update_fun) do
    user_file = user_file(user_id)
    user_file |> Path.dirname() |> File.mkdir_p!()

    lock_id = {user_id, self()}
    :global.set_lock(lock_id)

    user =
      case File.exists?(user_file) do
        true -> get_user(user_id)
        false -> %User{id: user_id}
      end

    result = update_fun.(user)
    result |> :erlang.term_to_binary() |> then(&File.write!(user_file, &1))
    :global.del_lock(lock_id)
    result
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user, token_inserted_at \\ DateTime.utc_now()) do
    signed_at = DateTime.to_unix(token_inserted_at)

    Phoenix.Token.sign(InvisibleThreadsWeb.Endpoint, @token_salt, {user.id, token_inserted_at},
      max_age: @session_validity_in_seconds,
      signed_at: signed_at
    )
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    with {:ok, {user_id, token_inserted_at}} <-
           Phoenix.Token.verify(InvisibleThreadsWeb.Endpoint, @token_salt, token,
             max_age: @session_validity_in_seconds
           ),
         %User{} = user <- get_user(user_id) do
      {user, token_inserted_at}
    else
      _invalid_token -> nil
    end
  end

  @doc """
  Logs the user in by Postmark Server API token.

  Validates the token against Postmark's API and migrates the user's SQLite database file.
  """
  def login_user_by_server_token(token) do
    with {:ok, %{"ID" => id, "InboundAddress" => inbound_address, "Name" => name}} <-
           Postmark.get_server(token) do
      user =
        update_user!(
          id,
          &struct!(&1,
            server_token: token,
            inbound_address: inbound_address,
            name: name,
            inbound_webhook_password:
              &1.inbound_webhook_password || new_inbound_webhook_password()
          )
        )

      # TODO: Offer to set Postmark webhook

      {:ok, user}
    end
  end

  defp new_inbound_webhook_password do
    :crypto.strong_rand_bytes(64) |> Base.url_encode64(padding: false) |> binary_part(0, 64)
  end
end
