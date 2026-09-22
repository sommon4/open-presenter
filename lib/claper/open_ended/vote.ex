defmodule Claper.OpenEnded.Vote do
  @moduledoc """
  One attendee's vote on one Open Ended response (one vote per attendee per
  response).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "open_ended_votes" do
    field :attendee_identifier, :string

    belongs_to :user, Claper.Accounts.User
    belongs_to :open_ended_response, Claper.OpenEnded.Response

    timestamps()
  end

  @doc false
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:attendee_identifier, :user_id, :open_ended_response_id])
    |> validate_required([:open_ended_response_id])
    |> unique_constraint([:open_ended_response_id, :attendee_identifier])
    |> unique_constraint([:open_ended_response_id, :user_id])
  end
end
