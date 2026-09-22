defmodule Claper.WordClouds.WordCloud do
  @moduledoc """
  A Word Cloud interaction: attendees send short free-text answers, the server
  merges equivalent answers and the presenter screen shows them sized by
  frequency.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type word :: %{text: String.t(), count: non_neg_integer()}

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          enabled: boolean() | nil,
          max_answers: integer(),
          max_characters: integer(),
          show_results: boolean(),
          merge_case: boolean(),
          moderation_enabled: boolean(),
          profanity_filter_enabled: boolean(),
          presentation_file_id: integer() | nil,
          words: [word()] | nil,
          total: integer() | nil,
          pending_count: integer() | nil,
          pending_responses: [Claper.WordClouds.WordCloudResponse.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :position,
             :enabled,
             :max_answers,
             :max_characters,
             :show_results,
             :words,
             :total
           ]}
  schema "word_clouds" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :max_answers, :integer, default: 3
    field :max_characters, :integer, default: 40
    field :show_results, :boolean, default: true
    field :merge_case, :boolean, default: true
    field :moderation_enabled, :boolean, default: false
    field :profanity_filter_enabled, :boolean, default: false

    # Aggregated words `[%{text: "...", count: n}]`, filled by
    # `Claper.WordClouds.with_words/1`.
    field :words, {:array, :map}, virtual: true
    field :total, :integer, virtual: true
    field :pending_count, :integer, virtual: true
    field :pending_responses, {:array, :map}, virtual: true

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    has_many :word_cloud_responses, Claper.WordClouds.WordCloudResponse, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(word_cloud, attrs \\ %{}) do
    word_cloud
    |> cast(attrs, [
      :title,
      :position,
      :enabled,
      :max_answers,
      :max_characters,
      :show_results,
      :merge_case,
      :moderation_enabled,
      :profanity_filter_enabled,
      :presentation_file_id
    ])
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
    |> validate_number(:max_answers, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:max_characters,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 100
    )
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
