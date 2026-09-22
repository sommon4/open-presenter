defmodule Claper.OpenEnded.Response do
  @moduledoc """
  One free-text answer to an Open Ended question.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending approved rejected)

  @type t :: %__MODULE__{
          id: integer(),
          text: String.t(),
          status: String.t(),
          vote_count: integer(),
          attendee_identifier: String.t() | nil,
          user_id: integer() | nil,
          open_ended_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:id, :text, :status, :vote_count, :inserted_at]}
  schema "open_ended_responses" do
    field :text, :string
    field :status, :string, default: "approved"
    field :vote_count, :integer, default: 0
    field :attendee_identifier, :string

    belongs_to :user, Claper.Accounts.User
    belongs_to :open_ended, Claper.OpenEnded.OpenEnded

    has_many :votes, Claper.OpenEnded.Vote, foreign_key: :open_ended_response_id

    timestamps()
  end

  def statuses, do: @statuses

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:text, :status, :vote_count, :attendee_identifier, :user_id, :open_ended_id])
    |> validate_required([:text, :open_ended_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:text, max: 1000)
  end

  @doc false
  def status_changeset(response, status) do
    response
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
  end
end
