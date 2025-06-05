defmodule InvisibleThreads.Accounts.User do
  use Ecto.Schema

  embedded_schema do
    field :inbound_address, :string
    field :inbound_webhook_password, :string, redact: true
    field :name, :string
    field :server_token, :string, redact: true
    embeds_many :email_threads, InvisibleThreads.Conversations.EmailThread
  end
end
