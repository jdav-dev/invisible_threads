defmodule InvisibleThreads.Conversations.EmailRecipient do
  @moduledoc """
  Participant in an invisible email thread.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @derive Jason.Encoder
  @derive {Swoosh.Email.Recipient, name: :name, address: :address}
  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :name, :string
    field :address, :string, redact: true
    field :first_message_id, :string
    field :unsubscribed?, :boolean, default: false
  end

  @doc false
  def changeset(email_recipient, attrs) do
    email_recipient
    |> cast(attrs, [:name, :address])
    |> validate_required([:name, :address])
    |> validate_length(:name, count: :codepoints, max: 255)
    # Postmark limits at least some addresses to 255 UTF-16 code points
    |> validate_length(:address, count: :codepoints, max: 255)
    |> put_change(:id, Ecto.UUID.generate())
  end
end
