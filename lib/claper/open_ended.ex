defmodule Claper.OpenEnded do
  @moduledoc """
  The OpenEnded context: free-text questions whose answers are shown as
  cards on the presenter screen, with optional voting and moderation.

  Broadcasts on the event topic: `:open_ended_created`,
  `:open_ended_updated` (also after every answer or vote) and
  `:open_ended_deleted`.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.OpenEnded.{OpenEnded, Response, Vote}
  alias Claper.WordClouds.{Normalizer, ProfanityFilter}

  @max_responses 500
  @rate_limit_ms 10_000
  @rate_limit_max 10

  @type identity :: integer() | String.t()

  ## Listing and fetching

  def list_open_ended(presentation_file_id) do
    from(o in OpenEnded,
      where: o.presentation_file_id == ^presentation_file_id,
      order_by: [asc: o.id, asc: o.position]
    )
    |> Repo.all()
  end

  def list_open_ended_at_position(presentation_file_id, position) do
    from(o in OpenEnded,
      where: o.presentation_file_id == ^presentation_file_id and o.position == ^position,
      order_by: [asc: o.id]
    )
    |> Repo.all()
    |> Enum.map(&with_responses/1)
  end

  def get_open_ended!(id), do: Repo.get!(OpenEnded, id) |> with_responses()

  def get_open_ended_for_event(id, event_id) do
    from(o in OpenEnded,
      join: pf in assoc(o, :presentation_file),
      where: o.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      open_ended -> with_responses(open_ended)
    end
  end

  def get_open_ended_current_position(presentation_file_id, position) do
    from(o in OpenEnded,
      where:
        o.position == ^position and o.presentation_file_id == ^presentation_file_id and
          o.enabled == true
    )
    |> Repo.one()
    |> case do
      nil -> nil
      open_ended -> with_responses(open_ended)
    end
  end

  @doc """
  Fills the virtual `responses` (approved, oldest first), `total` and
  `pending_count` fields.
  """
  def with_responses(%OpenEnded{} = open_ended) do
    responses = list_responses(open_ended.id, "approved")

    pending =
      if open_ended.moderation_enabled, do: list_responses(open_ended.id, "pending"), else: []

    %{
      open_ended
      | responses: responses,
        total: length(responses),
        pending_count: length(pending),
        pending_responses: pending
    }
  end

  def with_responses(other), do: other

  ## CRUD

  def create_open_ended(attrs \\ %{}) do
    %OpenEnded{}
    |> OpenEnded.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, open_ended} ->
        open_ended = Repo.preload(open_ended, presentation_file: :event)

        broadcast(
          {:ok, with_responses(open_ended), open_ended.presentation_file.event.uuid},
          :open_ended_created
        )

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  def update_open_ended(event_uuid, %OpenEnded{} = open_ended, attrs) do
    open_ended
    |> OpenEnded.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, open_ended} ->
        broadcast({:ok, with_responses(open_ended), event_uuid}, :open_ended_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  def delete_open_ended(event_uuid, %OpenEnded{} = open_ended) do
    {:ok, open_ended} = Repo.delete(open_ended)
    broadcast({:ok, open_ended, event_uuid}, :open_ended_deleted)
  end

  def change_open_ended(%OpenEnded{} = open_ended, attrs \\ %{}) do
    OpenEnded.changeset(open_ended, attrs)
  end

  def disable_all(presentation_file_id, position) do
    from(o in OpenEnded,
      where: o.presentation_file_id == ^presentation_file_id and o.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    Repo.get!(OpenEnded, id) |> Ecto.Changeset.change(enabled: true) |> Repo.update()
  end

  def set_disabled(id) do
    Repo.get!(OpenEnded, id) |> Ecto.Changeset.change(enabled: false) |> Repo.update()
  end

  ## Responses

  @doc """
  Submits one answer. Returns `{:ok, response, open_ended}` or
  `{:error, reason}` with reason one of `:disabled`, `:rate_limited`,
  `:empty`, `:too_long`, `:limit_reached`, `:full` or a changeset.
  """
  @spec submit_response(identity(), String.t(), OpenEnded.t(), String.t()) ::
          {:ok, Response.t(), OpenEnded.t()} | {:error, term()}
  def submit_response(identity, event_uuid, %OpenEnded{} = open_ended, text) do
    with :ok <- check_enabled(open_ended),
         :ok <- check_rate_limit(open_ended, identity),
         {:ok, %{display: display}} <-
           Normalizer.normalize(text,
             max_characters: open_ended.max_characters,
             merge_case: false
           ),
         :ok <- check_limits(open_ended, identity),
         {:ok, response} <- insert_response(open_ended, identity, display) do
      open_ended = with_responses(open_ended)
      broadcast({:ok, open_ended, event_uuid}, :open_ended_updated)
      {:ok, response, open_ended}
    end
  end

  defp check_enabled(%OpenEnded{enabled: true}), do: :ok
  defp check_enabled(_), do: {:error, :disabled}

  defp check_rate_limit(open_ended, identity) do
    case Claper.RateLimit.hit(
           "open_ended:#{open_ended.id}:#{identity}",
           @rate_limit_ms,
           @rate_limit_max
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  defp check_limits(open_ended, identity) do
    cond do
      not open_ended.multiple_responses and list_responses_for(identity, open_ended.id) != [] ->
        {:error, :limit_reached}

      count_responses(open_ended.id, "approved") + count_responses(open_ended.id, "pending") >=
          @max_responses ->
        {:error, :full}

      true ->
        :ok
    end
  end

  defp insert_response(open_ended, identity, text) do
    status =
      cond do
        open_ended.moderation_enabled -> "pending"
        ProfanityFilter.profane?(text) and profanity_blocks?() -> "pending"
        true -> "approved"
      end

    %Response{}
    |> Response.changeset(
      %{text: text, status: status, open_ended_id: open_ended.id}
      |> put_identity(identity)
    )
    |> Repo.insert()
  end

  # Profane answers are only held back when the instance configured a list.
  defp profanity_blocks?, do: Application.get_env(:claper, :word_cloud_profanity_words, []) != []

  defp put_identity(attrs, user_id) when is_integer(user_id),
    do: Map.put(attrs, :user_id, user_id)

  defp put_identity(attrs, attendee_identifier) when is_binary(attendee_identifier),
    do: Map.put(attrs, :attendee_identifier, attendee_identifier)

  def list_responses_for(user_id, open_ended_id) when is_integer(user_id) do
    from(r in Response,
      where:
        r.open_ended_id == ^open_ended_id and r.user_id == ^user_id and r.status != "rejected",
      order_by: [asc: r.id]
    )
    |> Repo.all()
  end

  def list_responses_for(attendee_identifier, open_ended_id)
      when is_binary(attendee_identifier) do
    from(r in Response,
      where:
        r.open_ended_id == ^open_ended_id and r.attendee_identifier == ^attendee_identifier and
          r.status != "rejected",
      order_by: [asc: r.id]
    )
    |> Repo.all()
  end

  def list_responses(open_ended_id, status \\ nil) do
    query = from(r in Response, where: r.open_ended_id == ^open_ended_id, order_by: [asc: r.id])
    query = if status, do: where(query, [r], r.status == ^status), else: query
    Repo.all(query)
  end

  def count_responses(open_ended_id, status) do
    from(r in Response,
      where: r.open_ended_id == ^open_ended_id and r.status == ^status,
      select: count(r.id)
    )
    |> Repo.one()
  end

  def get_response_for_event(id, event_id) do
    from(r in Response,
      join: o in assoc(r, :open_ended),
      join: pf in assoc(o, :presentation_file),
      where: r.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
  end

  def moderate_response(event_uuid, %Response{} = response, status)
      when status in ["approved", "rejected"] do
    response
    |> Response.status_changeset(status)
    |> Repo.update()
    |> case do
      {:ok, response} ->
        broadcast({:ok, get_open_ended!(response.open_ended_id), event_uuid}, :open_ended_updated)
        {:ok, response}

      error ->
        error
    end
  end

  def delete_response(event_uuid, %Response{} = response) do
    {:ok, response} = Repo.delete(response)
    broadcast({:ok, get_open_ended!(response.open_ended_id), event_uuid}, :open_ended_updated)
    {:ok, response}
  end

  def delete_all_responses(event_uuid, %OpenEnded{} = open_ended) do
    {count, _} =
      from(r in Response, where: r.open_ended_id == ^open_ended.id) |> Repo.delete_all()

    broadcast({:ok, with_responses(open_ended), event_uuid}, :open_ended_updated)
    {:ok, count}
  end

  ## Votes

  @doc """
  Toggles the attendee's vote on a response. Returns
  `{:ok, :voted | :unvoted, open_ended}` or `{:error, :voting_disabled}`.
  """
  def toggle_vote(
        identity,
        event_uuid,
        %OpenEnded{voting_enabled: true} = open_ended,
        response_id
      ) do
    response = Repo.get_by(Response, id: response_id, open_ended_id: open_ended.id)

    cond do
      is_nil(response) or response.status != "approved" ->
        {:error, :not_found}

      true ->
        result =
          case get_vote(identity, response.id) do
            nil ->
              %Vote{}
              |> Vote.changeset(%{open_ended_response_id: response.id} |> put_identity(identity))
              |> Repo.insert()
              |> case do
                {:ok, _} -> {:ok, :voted, 1}
                {:error, _} -> {:ok, :voted, 0}
              end

            vote ->
              Repo.delete!(vote)
              {:ok, :unvoted, -1}
          end

        {:ok, action, delta} = result

        from(r in Response, where: r.id == ^response.id)
        |> Repo.update_all(inc: [vote_count: delta])

        open_ended = with_responses(open_ended)
        broadcast({:ok, open_ended, event_uuid}, :open_ended_updated)
        {:ok, action, open_ended}
    end
  end

  def toggle_vote(_identity, _event_uuid, _open_ended, _response_id),
    do: {:error, :voting_disabled}

  defp get_vote(user_id, response_id) when is_integer(user_id),
    do: Repo.get_by(Vote, open_ended_response_id: response_id, user_id: user_id)

  defp get_vote(attendee_identifier, response_id) when is_binary(attendee_identifier),
    do:
      Repo.get_by(Vote,
        open_ended_response_id: response_id,
        attendee_identifier: attendee_identifier
      )

  @doc """
  Ids of the responses of an open ended question the attendee voted for.
  """
  def voted_response_ids(identity, open_ended_id) do
    base =
      from(v in Vote,
        join: r in assoc(v, :open_ended_response),
        where: r.open_ended_id == ^open_ended_id,
        select: v.open_ended_response_id
      )

    query =
      case identity do
        user_id when is_integer(user_id) -> where(base, [v], v.user_id == ^user_id)
        att when is_binary(att) -> where(base, [v], v.attendee_identifier == ^att)
      end

    Repo.all(query)
  end

  @doc """
  Rows for a CSV export: `[[text, votes, status, sent_at]]`.
  """
  def export_rows(open_ended_id) do
    list_responses(open_ended_id)
    |> Enum.map(fn r ->
      [r.text, r.vote_count, r.status, NaiveDateTime.to_string(r.inserted_at)]
    end)
  end

  defp broadcast({:ok, open_ended, event_uuid}, event) do
    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event_uuid}", {event, open_ended})
    {:ok, open_ended}
  end
end
