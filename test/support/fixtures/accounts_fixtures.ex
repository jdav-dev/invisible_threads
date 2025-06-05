defmodule InvisibleThreads.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `InvisibleThreads.Accounts` context.
  """

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Accounts.User

  def valid_user_server_token, do: Ecto.UUID.generate()

  def valid_user_attributes(attrs \\ %{}) do
    id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      id: id,
      inbound_address: "user_#{id}@example.com",
      name: "User #{id}",
      server_token: valid_user_server_token()
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
end
