defmodule InvisibleThreads.Repo.Migrations.CreateEmailThreads do
  use Ecto.Migration

  def change do
    create table(:email_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # 1000 is the max length of Postmark tags
      add :name, :string, null: false, size: 1000
      # 50 is the max number of recipients for a single Postmark email
      add :recipients, :map, null: false, size: 50

      timestamps type: :utc_datetime, updated_at: false
    end

    create unique_index(:email_threads, [:name])
  end
end
