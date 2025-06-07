defmodule InvisibleThreads.Accounts do
  @moduledoc """
  The Accounts context.
  """

  use InvisibleThreadsWeb, :verified_routes

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
  # `user_id` is used in a file name, but any directory structure is first stripped.  We should be
  # safe from directory traversal.
  # sobelow_skip ["Traversal.FileModule"]
  def get_user(id) do
    id
    |> user_file()
    |> File.read()
    |> case do
      {:ok, binary} -> Plug.Crypto.non_executable_binary_to_term(binary)
      _error -> nil
    end
  end

  defp user_file(id) do
    # Strip any directory structure from the ID
    basename = Path.basename("#{id}.etf")
    Path.join(data_dir(), basename)
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
  # `user_id` is used in a file name, but any directory structure is first stripped.  We should be
  # safe from directory traversal.
  # sobelow_skip ["Traversal.FileModule"]
  def update_user!(user_id, update_fun) do
    File.mkdir_p!(data_dir())
    user_file = user_file(user_id)

    lock_id = user_lock_id(user_id)
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

  defp user_lock_id(user_id) when is_integer(user_id) or is_binary(user_id) do
    {user_id, self()}
  end

  @doc """
  Deletes a single user.

  ## Examples

      iex> delete_user!(user)
      :ok

  """
  # `user_id` is used in a file name, but any directory structure is first stripped.  We should be
  # safe from directory traversal.
  # sobelow_skip ["Traversal.FileModule"]
  def delete_user!(user) do
    user_file = user_file(user.id)
    lock_id = user_lock_id(user.id)
    :global.set_lock(lock_id)
    File.rm!(user_file)
    :global.del_lock(lock_id)
    Postmark.set_inbound_hook_url(user.server_token, "")
    :ok
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
           Postmark.get_server(token),
         user <-
           update_user!(
             id,
             &struct!(&1,
               server_token: token,
               inbound_address: inbound_address,
               name: name,
               inbound_webhook_password:
                 &1.inbound_webhook_password || new_inbound_webhook_password()
             )
           ),
         :ok <- maybe_update_postmark(token, user) do
      {:ok, user}
    end
  end

  defp new_inbound_webhook_password do
    :crypto.strong_rand_bytes(64) |> Base.url_encode64(padding: false) |> binary_part(0, 64)
  end

  defp maybe_update_postmark(token, user) do
    case InvisibleThreadsWeb.Endpoint.host() do
      "localhost" -> :ok
      _other -> Postmark.set_inbound_hook_url(token, inbound_hook_url(user))
    end
  end

  defp inbound_hook_url(user) do
    url(~p"/api/postmark/inbound_webhook/#{user}")
    |> URI.new!()
    |> struct!(userinfo: "postmark:#{user.inbound_webhook_password}")
    |> to_string()
  end
end
