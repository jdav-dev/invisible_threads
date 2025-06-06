defmodule InvisibleThreadsWeb.PostmarkController do
  use InvisibleThreadsWeb, :controller

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Accounts.User
  alias InvisibleThreads.Conversations

  require Logger

  plug :auth

  def inbound_webhook(conn, params) do
    case Conversations.forward_inbound_email(conn.assigns.current_scope, params) do
      {:ok, message_id} ->
        json(conn, %{id: message_id})

      {:error, :unknown_thread} ->
        # 403 will stop Postmark from retrying
        send_resp(conn, 403, "Forbidden")

      {:error, reason} ->
        Logger.error(["Failed to forward email:\n\tReason: ", inspect(reason)])
        send_resp(conn, 500, "Internal Server Error")
    end
  end

  defp auth(conn, _opts) do
    %{"user_id" => user_id} = conn.params

    case Accounts.get_user(user_id) do
      %User{} = user ->
        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> Plug.BasicAuth.basic_auth(
          username: "postmark",
          password: user.inbound_webhook_password
        )

      nil ->
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end
