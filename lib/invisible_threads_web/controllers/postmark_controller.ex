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
      :ok ->
        resp(conn, 200, "")

      {:error, :unknown_thread} ->
        conn
        |> put_status(403)
        |> put_view(json: InvisibleThreadsWeb.ErrorJSON)
        |> render("403.json")

      {:error, reason} ->
        Logger.error(["Failed to forward email:\n\tReason: ", inspect(reason)])

        conn
        |> put_status(500)
        |> put_view(json: InvisibleThreadsWeb.ErrorJSON)
        |> render("500.json")
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
        conn |> put_status(401) |> render("401.json")
    end
  end
end
