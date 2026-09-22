defmodule Claper.Repo.Migrations.CreateWordClouds do
  use Ecto.Migration

  def change do
    create table(:word_clouds) do
      add :title, :string, null: false
      add :position, :integer, default: 0, null: false
      add :enabled, :boolean, default: false, null: false
      add :max_answers, :integer, default: 3, null: false
      add :max_characters, :integer, default: 40, null: false
      add :show_results, :boolean, default: true, null: false
      add :merge_case, :boolean, default: true, null: false
      add :moderation_enabled, :boolean, default: false, null: false
      add :profanity_filter_enabled, :boolean, default: false, null: false

      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:word_clouds, [:presentation_file_id])
    create index(:word_clouds, [:presentation_file_id, :position])

    create table(:word_cloud_responses) do
      add :original_text, :string, null: false
      add :normalized_text, :string, null: false
      add :status, :string, default: "approved", null: false
      add :attendee_identifier, :string
      add :user_id, references(:users, on_delete: :nilify_all)
      add :word_cloud_id, references(:word_clouds, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:word_cloud_responses, [:word_cloud_id])
    create index(:word_cloud_responses, [:word_cloud_id, :normalized_text])
    create index(:word_cloud_responses, [:word_cloud_id, :attendee_identifier])
    create index(:word_cloud_responses, [:word_cloud_id, :user_id])
  end
end
