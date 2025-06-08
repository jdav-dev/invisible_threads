defmodule InvisibleThreadsWeb.UserSessionControllerTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import InvisibleThreads.AccountsFixtures

  alias InvisibleThreads.Accounts

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/log-in - password" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"password" => user.server_token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/threads"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/threads")
      response = html_response(conn, 200)
      assert response =~ user.name
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "password" => user.server_token,
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_invisible_threads_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/threads"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "password" => user.server_token
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{
          "ErrorCode" => 10,
          "Message" => "Request does not contain a valid Server token."
        })
      end)

      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid Server API token"
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "redirects to login page when Postmark can't be reached", %{conn: conn, user: user} do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"password" => user.server_token}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Error calling Postmark API"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  test "GET /users/download-my-data returns a user's data as JSON", %{conn: conn, user: user} do
    conn = conn |> log_in_user(user) |> get(~p"/users/download-my-data")

    assert json_response(conn, 200) == %{
             "id" => user.id,
             "inbound_address" => user.inbound_address,
             "inbound_webhook_password" => user.inbound_webhook_password,
             "name" => user.name,
             "server_token" => user.server_token,
             "email_threads" => []
           }
  end

  test "DELETE /users/delete-my-data deletes the users's data and logs them out", %{
    conn: conn,
    user: user
  } do
    conn = conn |> log_in_user(user) |> delete(~p"/users/delete-my-data")
    assert redirected_to(conn) == ~p"/"
    refute get_session(conn, :user_token)
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User deleted successfully"
    refute Accounts.get_user(user.id)
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
