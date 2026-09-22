defmodule Claper.Repo.Migrations.CreateTranscriptionConfigs do
  use Ecto.Migration

  def change do
    create table(:transcription_configs) do
      add :enabled, :boolean, default: false
      add :visible, :boolean, default: true
      add :language, :string

      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:transcription_configs, [:presentation_file_id])

    alter table(:presentation_states) do
      remove :settings, :map, default: %{}
    end
  end
end
