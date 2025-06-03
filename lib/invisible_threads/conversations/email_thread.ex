defmodule InvisibleThreads.Conversations.EmailThread do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_threads" do
    field :name, :string
    field :tag, :string
    field :recipients, {:array, :string}
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(email_thread, attrs, user_scope) do
    email_thread
    |> cast(attrs, [:name, :tag, :recipients])
    |> validate_required([:name, :tag, :recipients])
    |> put_change(:user_id, user_scope.user.id)
  end
end
