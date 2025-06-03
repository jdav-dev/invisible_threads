defmodule InvisibleThreads.Repo.Migrations.CreateEmailThreads do
  use Ecto.Migration

  def change do
    create table(:email_threads) do
      add :name, :string
      add :tag, :string
      add :recipients, {:array, :string}
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:email_threads, [:user_id])
  end
end
