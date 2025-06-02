defmodule InvisibleThreads.Accounts.User do
  use Ecto.Schema

  embedded_schema do
    field :server_token, :string, redact: true
    field :inbound_address, :string
    field :name, :string
  end
end
