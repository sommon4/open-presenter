defmodule Claper.OpenEnded.OpenEnded do
  @moduledoc """
  An Open Ended question: attendees send free-text answers that the presenter
  screen shows as cards. Optionally attendees can vote on answers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          enabled: boolean() | nil,
          max_characters: integer(),
          multiple_responses: boolean(),
          voting_enabled: boolean(),
          auto_scroll: boolean(),
          show_results: boolean(),
          moderation_enabled: boolean(),
          presentation_file_id: integer() | nil,
          responses: [Claper.OpenEnded.Response.t()] | nil,
          total: integer() | nil,
          pending_count: integer() | nil,
          pending_responses: [Claper.OpenEnded.Response.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :position,
             :enabled,
             :max_characters,
             :multiple_responses,
             :voting_enabled,
             :auto_scroll,
             :show_results,
             :responses,
             :total
           ]}
  schema "open_ended" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :max_characters, :integer, default: 200
    field :multiple_responses, :boolean, default: true
    field :voting_enabled, :boolean, default: false
    field :auto_scroll, :boolean, default: false
    field :show_results, :boolean, default: true
    field :moderation_enabled, :boolean, default: false

    # Approved responses, oldest first, filled by
    # `Claper.OpenEnded.with_responses/1`.
    field :responses, {:array, :map}, virtual: true
    field :total, :integer, virtual: true
    field :pending_count, :integer, virtual: true
    field :pending_responses, {:array, :map}, virtual: true

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    has_many :open_ended_responses, Claper.OpenEnded.Response, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(open_ended, attrs \\ %{}) do
    open_ended
    |> cast(attrs, [
      :title,
      :position,
      :enabled,
      :max_characters,
      :multiple_responses,
      :voting_enabled,
      :auto_scroll,
      :show_results,
      :moderation_enabled,
      :presentation_file_id
    ])
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
    |> validate_number(:max_characters,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 1000
    )
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
