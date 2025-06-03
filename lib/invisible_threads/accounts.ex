defmodule InvisibleThreads.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias InvisibleThreads.Accounts.User
  alias InvisibleThreads.Accounts.UserToken
  alias InvisibleThreads.Postmark
  alias InvisibleThreads.Repo

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token()

    Repo.with_dynamic_repo(user, fn ->
      Repo.insert!(user_token)
    end)

    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `token_inserted_at` is returned, otherwise `nil` is returned.
  """
  def verify_session_token(user, token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.with_dynamic_repo(user, fn ->
      Repo.one(query)
    end)
  end

  @doc """
  Logs the user in by Postmark Server API token.

  Validates the token against Postmark's API and migrates the user's SQLite database file.
  """
  def login_user_by_server_token(token) do
    with {:ok, %{"ID" => id, "InboundAddress" => inbound_address, "Name" => name}} <-
           Postmark.get_server(token) do
      user = %User{id: id, server_token: token, inbound_address: inbound_address, name: name}
      Repo.migrate_user(user)
      {:ok, user}
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(user, token) do
    Repo.with_dynamic_repo(user, fn ->
      Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    end)

    :ok
  end
end
