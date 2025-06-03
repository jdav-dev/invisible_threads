defmodule InvisibleThreads.Conversations.EmailThread do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "email_threads" do
    field :name, :string
    embeds_many :recipients, InvisibleThreads.Conversations.EmailRecipient, on_replace: :delete

    timestamps type: :utc_datetime, updated_at: false
  end

  @doc false
  def changeset(email_thread, attrs, _user_scope) do
    email_thread
    |> cast(attrs, [:name])
    |> validate_required(:name)
    |> cast_embed(:recipients,
      required: true,
      sort_param: :recipients_sort,
      drop_param: :recipients_drop
    )
    # 1000 is the max length of Postmark tags
    |> validate_length(:name, max: 1000)
    # 50 is the max number of recipients for a single Postmark email
    |> validate_length(:recipients, max: 50)
    |> unique_constraint(:name)
  end
end
