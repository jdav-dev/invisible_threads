defmodule InvisibleThreads.Conversations.EmailThread do
  @moduledoc """
  `EmailThread` holds the information to send messages to an invisible email thread.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :message_stream, :string
    field :from, :string
    field :subject, :string
    embeds_many :recipients, InvisibleThreads.Conversations.EmailRecipient, on_replace: :delete

    timestamps type: :utc_datetime, updated_at: false
  end

  @doc false
  def changeset(email_thread, attrs, _user_scope) do
    email_thread
    |> cast(attrs, [:message_stream, :from, :subject])
    |> validate_required([:message_stream, :from, :subject])
    |> validate_format(:from, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> cast_embed(:recipients,
      required: true,
      sort_param: :recipients_sort,
      drop_param: :recipients_drop
    )
    |> validate_length(:message_stream, max: 255)
    |> validate_length(:from, max: 255)
    # 1000 is the max length of Postmark tags
    |> validate_length(:subject, max: 1000)
    # 50 is the max number of recipients for a single Postmark email
    |> validate_length(:recipients, max: 50)
  end

  def new(user_scope, attrs) do
    %__MODULE__{}
    |> changeset(attrs, user_scope)
    |> put_change(:id, Ecto.UUID.generate())
    |> put_change(:inserted_at, DateTime.utc_now())
    |> apply_action(:create)
  end
end
