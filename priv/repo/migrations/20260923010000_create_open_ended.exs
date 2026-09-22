defmodule Claper.Repo.Migrations.CreateOpenEnded do
  use Ecto.Migration

  def change do
    create table(:open_ended) do
      add :title, :string, null: false
      add :position, :integer, default: 0, null: false
      add :enabled, :boolean, default: false, null: false
      add :max_characters, :integer, default: 200, null: false
      add :multiple_responses, :boolean, default: true, null: false
      add :voting_enabled, :boolean, default: false, null: false
      add :auto_scroll, :boolean, default: false, null: false
      add :show_results, :boolean, default: true, null: false
      add :moderation_enabled, :boolean, default: false, null: false

      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:open_ended, [:presentation_file_id])
    create index(:open_ended, [:presentation_file_id, :position])

    create table(:open_ended_responses) do
      add :text, :text, null: false
      add :status, :string, default: "approved", null: false
      add :vote_count, :integer, default: 0, null: false
      add :attendee_identifier, :string
      add :user_id, references(:users, on_delete: :nilify_all)
      add :open_ended_id, references(:open_ended, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:open_ended_responses, [:open_ended_id])
    create index(:open_ended_responses, [:open_ended_id, :attendee_identifier])
    create index(:open_ended_responses, [:open_ended_id, :user_id])

    create table(:open_ended_votes) do
      add :attendee_identifier, :string
      add :user_id, references(:users, on_delete: :delete_all)

      add :open_ended_response_id, references(:open_ended_responses, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:open_ended_votes, [:open_ended_response_id, :attendee_identifier])
    create unique_index(:open_ended_votes, [:open_ended_response_id, :user_id])
  end
end
