defmodule InvisibleThreads.Conversations.EmailRecipient do
  @moduledoc """
  Participant in an invisible email thread.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @derive {Swoosh.Email.Recipient, name: :name, address: :address}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :address, :string, primary_key: true, redact: true
  end

  @doc false
  def changeset(email_recipient, attrs) do
    email_recipient
    |> cast(attrs, [:name, :address])
    |> validate_required([:name, :address])
    |> validate_length(:name, count: :codepoints, max: 255)
    # Postmark limits at least some addresses to 255 UTF-16 code points
    |> validate_length(:address, count: :codepoints, max: 255)
  end
end
