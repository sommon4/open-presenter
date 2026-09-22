defmodule Claper.Office do
  @moduledoc """
  The Office context: access tokens and event/interaction lookups for the
  PowerPoint add-in.

  Tokens look like `claper_office_<40 random chars>`; only their SHA-256 hash
  is stored.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Accounts.User
  alias Claper.Events
  alias Claper.Events.Event
  alias Claper.Office.Token

  @prefix "claper_office_"
  @random_bytes 30

  ## Tokens

  @doc """
  Lists the tokens of a user, newest first.
  """
  def list_tokens(%User{id: user_id}) do
    from(t in Token, where: t.user_id == ^user_id, order_by: [desc: t.id]) |> Repo.all()
  end

  @doc """
  Creates a token. Returns `{:ok, plain_token, %Token{}}`; the plain token is
  never retrievable again.
  """
  def create_token(%User{id: user_id}, name, scopes \\ Token.default_scopes()) do
    plain = @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@random_bytes), padding: false)

    %Token{}
    |> Token.changeset(%{
      name: name,
      token_hash: hash(plain),
      token_prefix: String.slice(plain, 0, String.length(@prefix) + 6),
      scopes: scopes,
      user_id: user_id
    })
    |> Repo.insert()
    |> case do
      {:ok, token} -> {:ok, plain, token}
      error -> error
    end
  end

  @doc """
  Deletes a token owned by the user.
  """
  def delete_token(%User{id: user_id}, token_id) do
    case Repo.get_by(Token, id: token_id, user_id: user_id) do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  @doc """
  Verifies a plain token. Returns `{:ok, %Token{user: %User{}}}` or
  `{:error, :invalid_token}`. Updates `last_used_at` at most once a minute.
  """
  def verify_token(@prefix <> _ = plain) do
    case Repo.get_by(Token, token_hash: hash(plain)) |> Repo.preload(:user) do
      nil -> {:error, :invalid_token}
      token -> {:ok, touch(token)}
    end
  end

  def verify_token(_), do: {:error, :invalid_token}

  def has_scope?(%Token{scopes: scopes}, scope), do: scope in scopes

  defp touch(%Token{last_used_at: last} = token) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    if is_nil(last) or NaiveDateTime.diff(now, last) > 60 do
      token |> Ecto.Changeset.change(last_used_at: now) |> Repo.update!()
    else
      token
    end
  end

  defp hash(plain), do: :crypto.hash(:sha256, plain)

  ## Events and interactions

  @doc """
  Events the user owns or facilitates, not expired, newest first.
  """
  def list_events(%User{} = user) do
    preload = [presentation_file: [:presentation_state]]
    owned = Events.list_not_expired_events(user.id, preload)
    managed = Events.list_managed_events_by(user.email, preload)

    (owned ++ managed)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.id, :desc)
  end

  @doc """
  Fetches an event by uuid if the user can manage it.
  """
  def get_event(%User{} = user, uuid) do
    with {:ok, _} <- Ecto.UUID.cast(uuid),
         %Event{} = event <-
           Repo.get_by(Event, uuid: uuid)
           |> Repo.preload(presentation_file: [:presentation_state]),
         true <- event.user_id == user.id or Events.led_by?(user.email, event) do
      {:ok, event}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Lists every interaction of an event, in slide order.
  """
  def list_interactions(%Event{presentation_file: pf}) do
    (Claper.Polls.list_polls(pf.id) ++
       Claper.Forms.list_forms(pf.id) ++
       Claper.Embeds.list_embeds(pf.id) ++
       Claper.Quizzes.list_quizzes(pf.id) ++
       Claper.WordClouds.list_word_clouds(pf.id) ++
       Claper.OpenEnded.list_open_ended(pf.id))
    |> Enum.sort_by(&{&1.position, &1.inserted_at})
  end

  @doc """
  Parses a public interaction id (`"poll_12"`, `"word_cloud_3"`, ...).
  """
  def parse_interaction_id(id) when is_binary(id) do
    with [type, num] <- Regex.run(~r/^([a-z_]+)_(\d+)$/, id, capture: :all_but_first),
         true <- type in ~w(poll form embed quiz word_cloud open_ended) do
      {:ok, type, String.to_integer(num)}
    else
      _ -> {:error, :invalid_id}
    end
  end

  def parse_interaction_id(_), do: {:error, :invalid_id}

  @doc """
  Fetches an interaction with fresh results, if the user can manage its event.
  Returns `{:ok, interaction, event}`.
  """
  def get_interaction(%User{} = user, id) do
    with {:ok, type, num} <- parse_interaction_id(id),
         {:ok, event_id} <- interaction_event_id(type, num),
         %Event{} = event <-
           Repo.get(Event, event_id) |> Repo.preload(presentation_file: [:presentation_state]),
         true <- event.user_id == user.id or Events.led_by?(user.email, event),
         interaction when not is_nil(interaction) <- load_interaction(type, num, event) do
      {:ok, interaction, event}
    else
      _ -> {:error, :not_found}
    end
  end

  defp interaction_event_id(type, num) do
    schema = schema_for(type)

    from(i in schema,
      join: pf in assoc(i, :presentation_file),
      where: i.id == ^num,
      select: pf.event_id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      event_id -> {:ok, event_id}
    end
  end

  defp schema_for("poll"), do: Claper.Polls.Poll
  defp schema_for("form"), do: Claper.Forms.Form
  defp schema_for("embed"), do: Claper.Embeds.Embed
  defp schema_for("quiz"), do: Claper.Quizzes.Quiz
  defp schema_for("word_cloud"), do: Claper.WordClouds.WordCloud
  defp schema_for("open_ended"), do: Claper.OpenEnded.OpenEnded

  @doc false
  def load_interaction("poll", id, event), do: Claper.Polls.get_poll_for_event(id, event.id)

  def load_interaction("form", id, event),
    do: Claper.Forms.get_form_for_event(id, event.id, [:form_submits])

  def load_interaction("embed", id, event), do: Claper.Embeds.get_embed_for_event(id, event.id)

  def load_interaction("quiz", id, event) do
    case Claper.Quizzes.get_quiz_for_event(id, event.id, quiz_questions: :quiz_question_opts) do
      nil -> nil
      quiz -> Claper.Quizzes.set_percentages(quiz)
    end
  end

  def load_interaction("word_cloud", id, event),
    do: Claper.WordClouds.get_word_cloud_for_event(id, event.id)

  def load_interaction("open_ended", id, event),
    do: Claper.OpenEnded.get_open_ended_for_event(id, event.id)

  @doc """
  Reloads an interaction struct with fresh results (used by the channel).
  """
  def reload(%{__struct__: schema, id: id}, event) do
    load_interaction(type_of(schema), id, event)
  end

  def type_of(Claper.Polls.Poll), do: "poll"
  def type_of(Claper.Forms.Form), do: "form"
  def type_of(Claper.Embeds.Embed), do: "embed"
  def type_of(Claper.Quizzes.Quiz), do: "quiz"
  def type_of(Claper.WordClouds.WordCloud), do: "word_cloud"
  def type_of(Claper.OpenEnded.OpenEnded), do: "open_ended"
  def type_of(%{__struct__: schema}), do: type_of(schema)

  def public_id(%{__struct__: schema, id: id}), do: "#{type_of(schema)}_#{id}"

  @doc """
  Activates or deactivates an interaction on behalf of the presenter.
  """
  def set_active(interaction, %Event{} = event, true) do
    with :ok <- Claper.Interactions.enable_interaction(interaction) do
      fresh = reload(interaction, event)
      broadcast_current(event, fresh)
      {:ok, fresh}
    end
  end

  def set_active(interaction, %Event{} = event, false) do
    with {:ok, _} <- Claper.Interactions.disable_interaction(interaction) do
      broadcast_current(event, nil)
      {:ok, reload(interaction, event)}
    end
  end

  defp broadcast_current(event, interaction) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event.uuid}",
      {:current_interaction, interaction}
    )
  end
end
