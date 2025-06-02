defmodule InvisibleThreads.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users_tokens) do
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:users_tokens, [:context, :token])
  end
end
