defmodule InvisibleThreads.AccountsTest do
  use InvisibleThreads.DataCase, async: true

  import InvisibleThreads.AccountsFixtures

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.User

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{user: user} do
      dt = ~U[2020-01-01T00:00:00Z]
      token = Accounts.generate_user_session_token(user, dt)
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "login_user_by_server_api_token/1" do
    test "validates the token with Postmark and returns a user" do
      token = valid_user_server_token()

      Req.Test.expect(InvisibleThreads.Postmark, 2, fn conn ->
        Req.Test.json(conn, %{
          "ID" => 12345,
          "InboundAddress" => "inbound@example.com",
          "Name" => "some name"
        })
      end)

      assert {:ok, user} = Accounts.login_user_by_server_token(token)
      assert user.id == 12345
      assert user.inbound_address == "inbound@example.com"
      assert user.name == "some name"
      assert is_binary(user.inbound_webhook_password)
      assert user.server_token == token

      # Assert that login works a second time and returns the same user.
      assert {:ok, user} == Accounts.login_user_by_server_token(token)
    end

    test "returns {:error, :invalid_token} if Postmark returns 401" do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{
          "ErrorCode" => 10,
          "Message" => "Request does not contain a valid Server token."
        })
      end)

      assert {:error, :invalid_token} = Accounts.login_user_by_server_token("some token")
    end

    test "returns :error for unexpected Postmark reponses" do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{
          "Message" => "Internal Server Error"
        })
      end)

      assert :error = Accounts.login_user_by_server_token(valid_user_server_token())
    end

    test "returns :error if Postmark cannot be reached" do
      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert :error = Accounts.login_user_by_server_token(valid_user_server_token())
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include inbound_webhook_password" do
      refute inspect(%User{inbound_webhook_password: "123456"}) =~
               "inbound_webhook_password: \"123456\""
    end

    test "does not include server_token" do
      refute inspect(%User{server_token: "123456"}) =~ "server_token: \"123456\""
    end
  end
end
