defmodule InvisibleThreads.AccountsTest do
  use InvisibleThreads.DataCase

  alias InvisibleThreads.Accounts

  import InvisibleThreads.AccountsFixtures
  alias InvisibleThreads.Accounts.{User, UserToken}

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert user_token =
               Repo.with_dynamic_repo(user, fn -> Repo.get_by(UserToken, token: token) end)

      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.with_dynamic_repo(user, fn ->
          Repo.insert!(%UserToken{
            token: user_token.token,
            context: "session"
          })
        end)
      end
    end
  end

  describe "verify_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert token_inserted_at = Accounts.verify_session_token(user, token)
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token", %{user: user} do
      refute Accounts.verify_session_token(user, "oops")
    end

    test "does not return user for expired token", %{user: user, token: token} do
      dt = ~N[2020-01-01 00:00:00]

      {1, nil} =
        Repo.with_dynamic_repo(user, fn ->
          Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
        end)

      refute Accounts.verify_session_token(user, token)
    end
  end

  describe "login_user_by_server_api_token/1" do
    test "validates the token with Postmark and migrates a DB" do
      token = valid_user_server_token()

      Req.Test.expect(InvisibleThreads.Postmark, fn conn ->
        Req.Test.json(conn, %{
          "ID" => 12345,
          "InboundAddress" => "inbound@example.com",
          "Name" => "some name"
        })
      end)

      assert {:ok, user} = Accounts.login_user_by_server_token(token)
      assert user.id == 12345
      assert user.server_token == token
      assert user.inbound_address == "inbound@example.com"
      assert user.name == "some name"
      assert Repo.with_dynamic_repo(user, fn -> Repo.query!("SELECT 1") end)
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

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(user, token) == :ok
      refute Accounts.verify_session_token(user, token)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include server_token" do
      refute inspect(%User{server_token: "123456"}) =~ "server_token: \"123456\""
    end
  end
end
