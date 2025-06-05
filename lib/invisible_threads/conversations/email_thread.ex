defmodule InvisibleThreads.Conversations.EmailThread do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :subject, :string
    embeds_many :recipients, InvisibleThreads.Conversations.EmailRecipient, on_replace: :delete
    field :first_message_id, :string

    timestamps type: :utc_datetime, updated_at: false
  end

  @doc false
  def changeset(email_thread, attrs, _user_scope) do
    email_thread
    |> cast(attrs, [:subject])
    |> validate_required(:subject)
    |> cast_embed(:recipients,
      required: true,
      sort_param: :recipients_sort,
      drop_param: :recipients_drop
    )
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
