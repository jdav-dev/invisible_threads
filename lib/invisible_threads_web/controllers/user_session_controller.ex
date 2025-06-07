defmodule InvisibleThreadsWeb.UserSessionController do
  use InvisibleThreadsWeb, :controller

  alias InvisibleThreads.Accounts
  alias InvisibleThreadsWeb.UserAuth

  def create(conn, params) do
    create(conn, params, "Welcome!")
  end

  # Server API token login
  defp create(conn, %{"user" => %{"password" => server_token} = user_params}, info) do
    case Accounts.login_user_by_server_token(server_token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid Server API token")
        |> redirect(to: ~p"/users/log-in")

      :error ->
        conn
        |> put_flash(:error, "Error calling Postmark API")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def download_data(conn, _params) do
    user = conn.assigns.current_scope.user

    send_download(conn, {:binary, Jason.encode!(user, pretty: true)},
      filename: "#{user.id}.json",
      content_type: "application/json",
      disposition: :inline,
      charset: "utf-8"
    )
  end

  def log_out(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
