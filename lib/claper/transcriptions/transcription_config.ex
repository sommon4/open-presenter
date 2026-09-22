defmodule Claper.Transcriptions.TranscriptionConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          enabled: boolean(),
          visibility: String.t(),
          language: String.t() | nil,
          presentation_file_id: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "transcription_configs" do
    field :enabled, :boolean, default: false
    field :visibility, :string, default: "both"
    field :language, :string

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:enabled, :visibility, :language, :presentation_file_id])
    |> validate_required([:presentation_file_id])
    |> validate_inclusion(:visibility, ["both", "presenter", "attendee"])
    |> unique_constraint(:presentation_file_id)
  end
end
