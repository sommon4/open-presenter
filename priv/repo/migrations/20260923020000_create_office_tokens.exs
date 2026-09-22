defmodule Claper.Repo.Migrations.CreateOfficeTokens do
  use Ecto.Migration

  def change do
    create table(:office_tokens) do
      add :name, :string, null: false
      add :token_hash, :binary, null: false
      add :token_prefix, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :last_used_at, :naive_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:office_tokens, [:token_hash])
    create index(:office_tokens, [:user_id])
  end
end
