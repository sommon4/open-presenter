defmodule Claper.Repo.Migrations.AddTranscriptionSupport do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :settings, :map, default: %{}
    end

    create table(:transcriptions) do
      add :text, :text, null: false
      add :segment_start, :float
      add :segment_end, :float
      add :language, :string

      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:transcriptions, [:presentation_file_id])
    create index(:transcriptions, [:inserted_at])
  end
end
