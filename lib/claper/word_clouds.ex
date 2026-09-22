defmodule Claper.WordClouds do
  @moduledoc """
  The WordClouds context.

  A Word Cloud is a native interaction (like a Poll or a Quiz). Attendees send
  short text answers; the context normalizes them, stores them, aggregates the
  frequencies and broadcasts the result on the event topic so that the
  manager, the presenter screen, the attendee phones and the PowerPoint add-in
  all receive the same data.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.WordClouds.{Normalizer, ProfanityFilter, WordCloud, WordCloudResponse}

  # Maximum number of distinct words sent to the clients.
  @max_words 150

  # Per attendee: at most `@rate_limit_max` submissions per `@rate_limit_ms`.
  @rate_limit_ms 10_000
  @rate_limit_max 10

  @type identity :: integer() | String.t()

  ## Listing and fetching

  @doc """
  Returns the list of word clouds for a given presentation file.
  """
  def list_word_clouds(presentation_file_id) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id,
      order_by: [asc: w.id, asc: w.position]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of word clouds for a given presentation file at a given
  position (slide).
  """
  def list_word_clouds_at_position(presentation_file_id, position) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id and w.position == ^position,
      order_by: [asc: w.id]
    )
    |> Repo.all()
    |> Enum.map(&with_words/1)
  end

  @doc """
  Gets a single word cloud with its aggregated words.

  Raises `Ecto.NoResultsError` if the word cloud does not exist.
  """
  def get_word_cloud!(id) do
    Repo.get!(WordCloud, id) |> with_words()
  end

  @doc """
  Gets a single word cloud scoped to the given event, with its aggregated
  words. Returns `nil` if it does not exist or does not belong to the event.
  """
  def get_word_cloud_for_event(id, event_id) do
    from(w in WordCloud,
      join: pf in assoc(w, :presentation_file),
      where: w.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      word_cloud -> with_words(word_cloud)
    end
  end

  @doc """
  Gets the enabled word cloud at a given position, with its aggregated words,
  or `nil`.
  """
  def get_word_cloud_current_position(presentation_file_id, position) do
    from(w in WordCloud,
      where:
        w.position == ^position and w.presentation_file_id == ^presentation_file_id and
          w.enabled == true
    )
    |> Repo.one()
    |> case do
      nil -> nil
      word_cloud -> with_words(word_cloud)
    end
  end

  ## Aggregation

  @doc """
  Fills the virtual `words`, `total` and `pending_count` fields of a word
  cloud.
  """
  def with_words(%WordCloud{} = word_cloud) do
    words = aggregate(word_cloud.id)

    pending =
      if word_cloud.moderation_enabled, do: list_responses(word_cloud.id, "pending"), else: []

    %{
      word_cloud
      | words: words,
        total: Enum.reduce(words, 0, fn %{count: c}, acc -> acc + c end),
        pending_count: length(pending),
        pending_responses: pending
    }
  end

  def with_words(other), do: other

  @doc """
  Aggregates approved responses of a word cloud into
  `[%{text: "genetics", count: 17}, ...]`, sorted by descending count then
  text. The display text is the earliest submitted form of that key.
  """
  def aggregate(word_cloud_id) do
    from(r in WordCloudResponse,
      where: r.word_cloud_id == ^word_cloud_id and r.status == "approved",
      group_by: r.normalized_text,
      select: %{
        key: r.normalized_text,
        count: count(r.id),
        text: fragment("(array_agg(? ORDER BY ? ASC))[1]", r.original_text, r.id)
      },
      order_by: [desc: count(r.id), asc: r.normalized_text],
      limit: @max_words
    )
    |> Repo.all()
    |> Enum.map(fn %{text: text, count: count} -> %{text: text, count: count} end)
  end

  @doc """
  Maps a word list to font sizes in pixels using a square-root scale, which
  keeps a dominant answer from crushing the others.

  Returns `[%{text: _, count: _, size: _}]`.
  """
  def with_sizes(words, min_size \\ 24, max_size \\ 96)

  def with_sizes([], _min_size, _max_size), do: []

  def with_sizes(words, min_size, max_size) do
    counts = Enum.map(words, & &1.count)
    min_count = Enum.min(counts)
    max_count = Enum.max(counts)

    Enum.map(words, fn %{count: count} = word ->
      size =
        if max_count == min_count do
          round((min_size + max_size) / 2)
        else
          ratio = :math.sqrt((count - min_count) / (max_count - min_count))
          round(min_size + ratio * (max_size - min_size))
        end

      Map.put(word, :size, size)
    end)
  end

  ## CRUD

  @doc """
  Creates a word cloud.
  """
  def create_word_cloud(attrs \\ %{}) do
    %WordCloud{}
    |> WordCloud.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, word_cloud} ->
        word_cloud = Repo.preload(word_cloud, presentation_file: :event)

        broadcast(
          {:ok, with_words(word_cloud), word_cloud.presentation_file.event.uuid},
          :word_cloud_created
        )

      {:error, changeset} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Updates a word cloud.
  """
  def update_word_cloud(event_uuid, %WordCloud{} = word_cloud, attrs) do
    word_cloud
    |> WordCloud.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, word_cloud} ->
        broadcast({:ok, with_words(word_cloud), event_uuid}, :word_cloud_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a word cloud and all of its responses.
  """
  def delete_word_cloud(event_uuid, %WordCloud{} = word_cloud) do
    {:ok, word_cloud} = Repo.delete(word_cloud)
    broadcast({:ok, word_cloud, event_uuid}, :word_cloud_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word cloud changes.
  """
  def change_word_cloud(%WordCloud{} = word_cloud, attrs \\ %{}) do
    WordCloud.changeset(word_cloud, attrs)
  end

  def disable_all(presentation_file_id, position) do
    from(w in WordCloud,
      where: w.presentation_file_id == ^presentation_file_id and w.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_enabled(id) do
    Repo.get!(WordCloud, id)
    |> Ecto.Changeset.change(enabled: true)
    |> Repo.update()
  end

  def set_disabled(id) do
    Repo.get!(WordCloud, id)
    |> Ecto.Changeset.change(enabled: false)
    |> Repo.update()
  end

  ## Responses

  @doc """
  Submits one answer to a word cloud.

  `identity` is a user id (integer) for logged-in attendees or the
  `attendee_identifier` string for anonymous attendees.

  Returns `{:ok, response, word_cloud}` where `word_cloud` carries the fresh
  aggregation, or `{:error, reason}` with reason one of `:disabled`,
  `:rate_limited`, `:empty`, `:too_long`, `:profanity`, `:limit_reached`,
  `:duplicate` or an `%Ecto.Changeset{}`.
  """
  @spec submit_response(identity(), String.t(), WordCloud.t(), String.t()) ::
          {:ok, WordCloudResponse.t(), WordCloud.t()} | {:error, term()}
  def submit_response(identity, event_uuid, %WordCloud{} = word_cloud, text) do
    with :ok <- check_enabled(word_cloud),
         :ok <- check_rate_limit(word_cloud, identity),
         {:ok, %{display: display, normalized: normalized}} <-
           Normalizer.normalize(text,
             max_characters: word_cloud.max_characters,
             merge_case: word_cloud.merge_case
           ),
         :ok <- check_profanity(word_cloud, normalized),
         :ok <- check_limits(word_cloud, identity, normalized),
         {:ok, response} <- insert_response(word_cloud, identity, display, normalized) do
      word_cloud = with_words(word_cloud)
      broadcast({:ok, word_cloud, event_uuid}, :word_cloud_updated)
      {:ok, response, word_cloud}
    end
  end

  defp check_enabled(%WordCloud{enabled: true}), do: :ok
  defp check_enabled(_), do: {:error, :disabled}

  defp check_rate_limit(word_cloud, identity) do
    case Claper.RateLimit.hit(
           "word_cloud:#{word_cloud.id}:#{identity}",
           @rate_limit_ms,
           @rate_limit_max
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  defp check_profanity(%WordCloud{profanity_filter_enabled: true}, normalized) do
    if ProfanityFilter.profane?(normalized), do: {:error, :profanity}, else: :ok
  end

  defp check_profanity(_word_cloud, _normalized), do: :ok

  defp check_limits(word_cloud, identity, normalized) do
    responses = list_responses_for(identity, word_cloud.id)

    cond do
      Enum.any?(responses, &(&1.normalized_text == normalized)) -> {:error, :duplicate}
      length(responses) >= word_cloud.max_answers -> {:error, :limit_reached}
      true -> :ok
    end
  end

  defp insert_response(word_cloud, identity, display, normalized) do
    status = if word_cloud.moderation_enabled, do: "pending", else: "approved"

    attrs =
      %{
        original_text: display,
        normalized_text: normalized,
        status: status,
        word_cloud_id: word_cloud.id
      }
      |> put_identity(identity)

    %WordCloudResponse{}
    |> WordCloudResponse.changeset(attrs)
    |> Repo.insert()
  end

  defp put_identity(attrs, user_id) when is_integer(user_id),
    do: Map.put(attrs, :user_id, user_id)

  defp put_identity(attrs, attendee_identifier) when is_binary(attendee_identifier),
    do: Map.put(attrs, :attendee_identifier, attendee_identifier)

  @doc """
  Lists the responses of one attendee to a word cloud (any status except
  rejected), oldest first.
  """
  def list_responses_for(user_id, word_cloud_id) when is_integer(user_id) do
    from(r in WordCloudResponse,
      where:
        r.word_cloud_id == ^word_cloud_id and r.user_id == ^user_id and r.status != "rejected",
      order_by: [asc: r.id]
    )
    |> Repo.all()
  end

  def list_responses_for(attendee_identifier, word_cloud_id)
      when is_binary(attendee_identifier) do
    from(r in WordCloudResponse,
      where:
        r.word_cloud_id == ^word_cloud_id and r.attendee_identifier == ^attendee_identifier and
          r.status != "rejected",
      order_by: [asc: r.id]
    )
    |> Repo.all()
  end

  @doc """
  Lists all responses of a word cloud, optionally filtered by status.
  """
  def list_responses(word_cloud_id, status \\ nil) do
    query =
      from(r in WordCloudResponse,
        where: r.word_cloud_id == ^word_cloud_id,
        order_by: [asc: r.id]
      )

    query = if status, do: where(query, [r], r.status == ^status), else: query

    Repo.all(query)
  end

  def count_responses(word_cloud_id, status) do
    from(r in WordCloudResponse,
      where: r.word_cloud_id == ^word_cloud_id and r.status == ^status,
      select: count(r.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets a response scoped to an event, or `nil`.
  """
  def get_response_for_event(id, event_id) do
    from(r in WordCloudResponse,
      join: w in assoc(r, :word_cloud),
      join: pf in assoc(w, :presentation_file),
      where: r.id == ^id and pf.event_id == ^event_id
    )
    |> Repo.one()
  end

  @doc """
  Approves or rejects a pending response and broadcasts the new aggregation.
  """
  def moderate_response(event_uuid, %WordCloudResponse{} = response, status)
      when status in ["approved", "rejected"] do
    response
    |> WordCloudResponse.status_changeset(status)
    |> Repo.update()
    |> case do
      {:ok, response} ->
        word_cloud = get_word_cloud!(response.word_cloud_id)
        broadcast({:ok, word_cloud, event_uuid}, :word_cloud_updated)
        {:ok, response}

      error ->
        error
    end
  end

  @doc """
  Deletes one response (presenter removes a word from the cloud) and
  broadcasts the new aggregation.
  """
  def delete_response(event_uuid, %WordCloudResponse{} = response) do
    {:ok, response} = Repo.delete(response)
    word_cloud = get_word_cloud!(response.word_cloud_id)
    broadcast({:ok, word_cloud, event_uuid}, :word_cloud_updated)
    {:ok, response}
  end

  @doc """
  Deletes every response whose key is `normalized_text`, which removes that
  word from the cloud.
  """
  def delete_word(event_uuid, %WordCloud{} = word_cloud, normalized_text) do
    {count, _} =
      from(r in WordCloudResponse,
        where: r.word_cloud_id == ^word_cloud.id and r.normalized_text == ^normalized_text
      )
      |> Repo.delete_all()

    broadcast({:ok, with_words(word_cloud), event_uuid}, :word_cloud_updated)
    {:ok, count}
  end

  @doc """
  Deletes every response of a word cloud (reset).
  """
  def delete_all_responses(event_uuid, %WordCloud{} = word_cloud) do
    {count, _} =
      from(r in WordCloudResponse, where: r.word_cloud_id == ^word_cloud.id)
      |> Repo.delete_all()

    broadcast({:ok, with_words(word_cloud), event_uuid}, :word_cloud_updated)
    {:ok, count}
  end

  @doc """
  Rows for a CSV export: `[[display, key, count]]`.
  """
  def export_rows(word_cloud_id) do
    aggregate(word_cloud_id)
    |> Enum.map(fn %{text: text, count: count} ->
      [text, Normalizer.key(text, true), count]
    end)
  end

  defp broadcast({:ok, word_cloud, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, word_cloud}
    )

    {:ok, word_cloud}
  end
end
