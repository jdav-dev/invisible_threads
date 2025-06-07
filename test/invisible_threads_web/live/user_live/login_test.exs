defmodule InvisibleThreadsWeb.UserLive.LoginTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import InvisibleThreads.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in with Postmark Server API token"
      assert html =~ "Log in"
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form", user: %{password: user.server_token, remember_me: true})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/threads"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{
          "ErrorCode" => 10,
          "Message" => "Request does not contain a valid Server token."
        })
      end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form", user: %{password: "123456", remember_me: true})

      render_submit(form)

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid Server API token"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
