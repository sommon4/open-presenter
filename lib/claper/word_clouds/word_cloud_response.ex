defmodule Claper.WordClouds.WordCloudResponse do
  @moduledoc """
  One answer sent by one attendee to a Word Cloud.

  `original_text` keeps the display form (trimmed, whitespace collapsed).
  `normalized_text` is the aggregation key produced by
  `Claper.WordClouds.Normalizer`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending approved rejected)

  @type t :: %__MODULE__{
          id: integer(),
          original_text: String.t(),
          normalized_text: String.t(),
          status: String.t(),
          attendee_identifier: String.t() | nil,
          user_id: integer() | nil,
          word_cloud_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:id, :original_text, :normalized_text, :status, :inserted_at]}
  schema "word_cloud_responses" do
    field :original_text, :string
    field :normalized_text, :string
    field :status, :string, default: "approved"
    field :attendee_identifier, :string

    belongs_to :user, Claper.Accounts.User
    belongs_to :word_cloud, Claper.WordClouds.WordCloud

    timestamps()
  end

  def statuses, do: @statuses

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [
      :original_text,
      :normalized_text,
      :status,
      :attendee_identifier,
      :user_id,
      :word_cloud_id
    ])
    |> validate_required([:original_text, :normalized_text, :word_cloud_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:original_text, max: 100)
    |> validate_length(:normalized_text, max: 100)
  end

  @doc false
  def status_changeset(response, status) do
    response
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
  end
end
