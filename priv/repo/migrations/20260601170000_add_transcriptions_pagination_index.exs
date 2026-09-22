defmodule Claper.Repo.Migrations.AddTranscriptionsPaginationIndex do
  use Ecto.Migration

  def change do
    create index(:transcriptions, [:presentation_file_id, :inserted_at, :id])
  end
end
