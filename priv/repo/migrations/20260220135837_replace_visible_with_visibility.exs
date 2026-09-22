defmodule Claper.Repo.Migrations.ReplaceVisibleWithVisibility do
  use Ecto.Migration

  def change do
    alter table(:transcription_configs) do
      add :visibility, :string, default: "both"
    end

    flush()

    execute "UPDATE transcription_configs SET visibility = CASE WHEN visible = true THEN 'both' ELSE 'presenter' END",
            "UPDATE transcription_configs SET visible = (visibility = 'both')"

    alter table(:transcription_configs) do
      remove :visible, :boolean, default: true
    end
  end
end
