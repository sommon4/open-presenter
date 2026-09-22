defmodule Claper.Transcriptions.Transcription do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    max_limit: 100,
    default_limit: 25,
    pagination_types: [:page],
    filterable: [],
    sortable: [:inserted_at, :id],
    default_order: %{
      order_by: [:inserted_at, :id],
      order_directions: [:asc, :asc]
    }
  }

  @type t :: %__MODULE__{
          id: integer(),
          text: String.t(),
          segment_start: float() | nil,
          segment_end: float() | nil,
          language: String.t() | nil,
          presentation_file_id: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "transcriptions" do
    field :text, :string
    field :segment_start, :float
    field :segment_end, :float
    field :language, :string

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(transcription, attrs) do
    transcription
    |> cast(attrs, [:text, :segment_start, :segment_end, :language, :presentation_file_id])
    |> validate_required([:text, :presentation_file_id])
  end
end
