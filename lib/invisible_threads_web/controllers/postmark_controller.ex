defmodule InvisibleThreadsWeb.PostmarkController do
  use InvisibleThreadsWeb, :controller

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.User
  alias InvisibleThreads.Conversations

  plug :auth

  def inbound_webhook(conn, params) do
    case Conversations.forward_inbound_email(params) do
      :ok ->
        resp(conn, 200, "")

      {:error, :unknown_thread} ->
        conn |> put_status(403) |> json(%{errors: %{detail: :unknown_thread}})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{errors: %{detail: reason}})
    end
  end

  defp auth(conn, _opts) do
    %{"user_id" => user_id} = conn.params

    case Accounts.get_user(user_id) do
      %User{} = user ->
        Plug.BasicAuth.basic_auth(conn,
          username: "postmark",
          password: user.inbound_webhook_password
        )

      nil ->
        conn |> put_status(401) |> render("401.json")
    end
  end
end
