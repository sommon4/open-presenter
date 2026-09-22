defmodule Claper.Repo.Migrations.CreateGlobalConfigs do
  use Ecto.Migration

  def change do
    create table(:global_configs) do
      add :key, :string, null: false
      add :value, :text
      add :encrypted_value, :binary

      timestamps()
    end

    create unique_index(:global_configs, [:key])
  end
end
