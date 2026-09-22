defmodule Claper.Office.Serializer do
  @moduledoc """
  Builds the JSON maps returned by the Office API and pushed on the Office
  channel. The same shapes are used everywhere so the PowerPoint add-in and
  the browser presenter show identical data.
  """

  alias Claper.Office

  def event(%Claper.Events.Event{} = event) do
    state =
      case event.presentation_file do
        %{presentation_state: %Claper.Presentations.PresentationState{} = state} -> state
        _ -> nil
      end

    %{
      id: event.uuid,
      name: event.name,
      code: event.code,
      join_code: String.upcase(event.code),
      join_url: join_url(event),
      started_at: event.started_at,
      expired_at: event.expired_at,
      slides: (event.presentation_file && event.presentation_file.length) || 0,
      position: state && state.position
    }
  end

  def join_url(%Claper.Events.Event{code: code}) do
    ClaperWeb.Endpoint.url() <> "/e/" <> code
  end

  def state(%Claper.Presentations.PresentationState{} = state) do
    %{
      position: state.position,
      join_screen_visible: state.join_screen_visible,
      poll_visible: state.poll_visible,
      chat_visible: state.chat_visible,
      poll_layout: state.poll_layout,
      poll_size: state.poll_size,
      poll_corner: state.poll_corner
    }
  end

  @doc """
  Serializes an interaction. `event` adds join metadata.
  """
  def interaction(interaction, event \\ nil)

  def interaction(nil, _event), do: nil

  def interaction(interaction, event) do
    base = %{
      id: Office.public_id(interaction),
      numeric_id: interaction.id,
      type: Office.type_of(interaction),
      title: title(interaction),
      position: interaction.position,
      enabled: interaction.enabled == true,
      results: results(interaction)
    }

    if event do
      Map.merge(base, %{
        event_id: event.uuid,
        join_code: String.upcase(event.code),
        join_url: join_url(event)
      })
    else
      base
    end
  end

  defp title(%{title: title}), do: title
  defp title(_), do: nil

  defp results(%Claper.Polls.Poll{} = poll) do
    poll = Claper.Polls.set_percentages(poll)
    opts = if is_list(poll.poll_opts), do: poll.poll_opts, else: []

    %{
      multiple: poll.multiple == true,
      show_results: poll.show_results != false,
      total_votes: Enum.reduce(opts, 0, &(&1.vote_count + &2)),
      options:
        Enum.map(opts, fn o ->
          %{
            id: o.id,
            content: o.content,
            vote_count: o.vote_count,
            percentage: to_number(o.percentage)
          }
        end)
    }
  end

  defp results(%Claper.WordClouds.WordCloud{} = wc) do
    words = wc.words || []

    %{
      total: wc.total || 0,
      show_results: wc.show_results,
      max_answers: wc.max_answers,
      max_characters: wc.max_characters,
      words: Claper.WordClouds.with_sizes(words)
    }
  end

  defp results(%Claper.OpenEnded.OpenEnded{} = oe) do
    %{
      total: oe.total || 0,
      show_results: oe.show_results,
      voting_enabled: oe.voting_enabled,
      auto_scroll: oe.auto_scroll,
      multiple_responses: oe.multiple_responses,
      max_characters: oe.max_characters,
      responses:
        Enum.map(oe.responses || [], fn r ->
          %{id: r.id, text: r.text, vote_count: r.vote_count, inserted_at: r.inserted_at}
        end)
    }
  end

  defp results(%Claper.Quizzes.Quiz{} = quiz) do
    questions = if is_list(quiz.quiz_questions), do: quiz.quiz_questions, else: []

    %{
      show_results: quiz.show_results,
      questions:
        Enum.map(questions, fn q ->
          opts = if is_list(q.quiz_question_opts), do: q.quiz_question_opts, else: []

          %{
            id: q.id,
            content: q.content,
            type: q.type,
            options:
              Enum.map(opts, fn o ->
                %{
                  id: o.id,
                  content: o.content,
                  is_correct: o.is_correct,
                  response_count: o.response_count,
                  percentage: to_number(o.percentage)
                }
              end)
          }
        end)
    }
  end

  defp results(%Claper.Forms.Form{} = form) do
    submits = if is_list(form.form_submits), do: form.form_submits, else: []
    fields = if is_list(form.fields), do: form.fields, else: []

    %{
      submit_count: length(submits),
      fields: Enum.map(fields, &%{name: &1.name, type: &1.type})
    }
  end

  defp results(%Claper.Embeds.Embed{} = embed) do
    %{provider: embed.provider, content: embed.content}
  end

  defp results(_), do: %{}

  def post(%Claper.Posts.Post{} = post) do
    %{
      id: post.uuid,
      body: post.body,
      name: post.name,
      pinned: post.pinned,
      like_count: post.like_count,
      love_count: post.love_count,
      lol_count: post.lol_count,
      position: post.position,
      inserted_at: post.inserted_at
    }
  end

  defp to_number(nil), do: 0
  defp to_number(n) when is_number(n), do: n

  defp to_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0
    end
  end
end
