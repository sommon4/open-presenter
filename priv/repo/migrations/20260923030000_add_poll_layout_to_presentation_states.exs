defmodule Claper.Repo.Migrations.AddPollLayoutToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      # overlay | side | corner | bottom
      add :poll_layout, :string, default: "overlay", null: false

      # percentage of the screen used by the interaction panel (side: width, bottom: height, corner: width)
      add :poll_size, :integer, default: 40, null: false
      # top-left | top-right | bottom-left | bottom-right (corner layout only)
      add :poll_corner, :string, default: "bottom-right", null: false
    end
  end
end
