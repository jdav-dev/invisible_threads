defmodule InvisibleThreads.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `InvisibleThreads.Accounts` context.
  """

  import Ecto.Query

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Accounts.User

  def valid_user_server_token, do: Ecto.UUID.generate()

  def valid_user_attributes(attrs \\ %{}) do
    id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      id: id,
      server_token: valid_user_server_token(),
      inbound_address: "user_#{id}@example.com",
      name: "User #{id}"
    })
  end

  def user_fixture(attrs \\ %{}) do
    user =
      attrs
      |> valid_user_attributes()
      |> then(&struct!(User, &1))

    Req.Test.stub(InvisibleThreads.Postmark, fn conn ->
      Req.Test.json(conn, %{
        "ID" => user.id,
        "InboundAddress" => user.inbound_address,
        "Name" => user.name
      })
    end)

    {:ok, user} = Accounts.login_user_by_server_token(user.server_token)

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def override_token_authenticated_at(user, token, authenticated_at) when is_binary(token) do
    InvisibleThreads.Repo.with_dynamic_repo(user, fn ->
      InvisibleThreads.Repo.update_all(
        from(t in Accounts.UserToken,
          where: t.token == ^token
        ),
        set: [authenticated_at: authenticated_at]
      )
    end)
  end

  def offset_user_token(user, token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    InvisibleThreads.Repo.with_dynamic_repo(user, fn ->
      InvisibleThreads.Repo.update_all(
        from(ut in Accounts.UserToken, where: ut.token == ^token),
        set: [inserted_at: dt, authenticated_at: dt]
      )
    end)
  end
end
