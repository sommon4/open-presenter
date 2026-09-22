defmodule Claper.Repo.Migrations.AddSlideOrderToPresentationFiles do
  use Ecto.Migration

  def change do
    alter table(:presentation_files) do
      add :slide_order, {:array, :integer}
    end
  end
end
