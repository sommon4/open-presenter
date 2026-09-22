defmodule ClaperWeb.EventLive.ManageInteractionOptionsComponent do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  def render(assigns) do
    assigns = assigns |> assign_new(:show_shortcut, fn -> true end)

    ~H"""
    <div class="flex flex-col gap-2 border border-gray-200 rounded-2xl p-2 bg-white shadow-lg">
      <div class="flex items-center gap-2">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="icon icon-tabler icons-tabler-outline icon-tabler-pointer-cog shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M15.774 13.218l-.996 -.996l3.113 -2.09a1.2 1.2 0 0 0 -.309 -2.228l-13.582 -3.904l3.904 13.563a1.2 1.2 0 0 0 2.228 .308l2.09 -3.093l.343 .343" />
          <path d="M17.001 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" />
          <path d="M19.001 15.5v1.5" />
          <path d="M19.001 21v1.5" />
          <path d="M22.032 17.25l-1.299 .75" />
          <path d="M17.27 20l-1.3 .75" />
          <path d="M15.97 17.25l1.3 .75" />
          <path d="M20.733 20l1.3 .75" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">
          {gettext("Current Interaction Settings")}
        </span>
      </div>

      <div class="space-y-2 px-1">
        <%= case @current_interaction do %>
          <% %Claper.Polls.Poll{} -> %>
            <.toggle_row
              label={
                if @state.poll_visible,
                  do: gettext("Hide results on presentation"),
                  else: gettext("Show results on presentation")
              }
              checked={@state.poll_visible}
              key={:poll_visible}
              shortcut={if @create == nil, do: "Z", else: nil}
              show_shortcut={@show_shortcut}
            >
              <:icon>
                <svg
                  :if={@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-5 w-5"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                </svg>
                <svg
                  :if={!@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-5 w-5"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                </svg>
              </:icon>
            </.toggle_row>

            <.layout_settings state={@state} />

            <% poll_total = poll_total(@current_interaction) %>
            <div class="rounded-2xl border border-gray-200 bg-white px-3 py-2" data-poll-votes>
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs font-semibold text-gray-700">
                  {ngettext("%{count} vote", "%{count} votes", poll_total)}
                </span>
                <button
                  :if={poll_total > 0}
                  type="button"
                  phx-click="poll-reset"
                  phx-value-id={@current_interaction.id}
                  data-confirm={
                    gettext(
                      "This will delete every vote of this poll and all attendees will be able to vote again, are you sure?"
                    )
                  }
                  class="text-xs font-semibold text-supporting-red-500 hover:underline"
                >
                  {gettext("Reset votes")}
                </button>
              </div>
            </div>
          <% %Claper.Quizzes.Quiz{} -> %>
            <div class="space-y-2">
              <.toggle_row
                label={
                  if @current_interaction.show_results,
                    do: gettext("Hide results on presentation"),
                    else: gettext("Show results on presentation")
                }
                checked={@current_interaction.show_results}
                key={:quiz_show_results}
                shortcut={if @create == nil, do: "Z", else: nil}
                show_shortcut={@show_shortcut}
              >
                <:icon>
                  <svg
                    :if={@current_interaction.show_results}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                  </svg>
                  <svg
                    :if={!@current_interaction.show_results}
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.action_row
                label={gettext("Review questions")}
                key={:review_quiz_questions}
                disabled={!@current_interaction.show_results}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="w-5 h-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 13a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M15 9a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M9 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v14a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M4 20h14" />
                  </svg>
                </:icon>
              </.action_row>

              <div class="grid grid-cols-2 gap-2">
                <.action_row
                  label={gettext("Previous")}
                  key={:prev_quiz_question}
                  disabled={!@current_interaction.show_results}
                  compact
                >
                  <:icon>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M11.78 5.22a.75.75 0 0 1 0 1.06L8.06 10l3.72 3.72a.75.75 0 1 1-1.06 1.06l-4.25-4.25a.75.75 0 0 1 0-1.06l4.25-4.25a.75.75 0 0 1 1.06 0Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </:icon>
                </.action_row>

                <.action_row
                  label={gettext("Next")}
                  key={:next_quiz_question}
                  disabled={!@current_interaction.show_results}
                  compact
                  reverse
                >
                  <:icon>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      class="w-5 h-5"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.22 5.22a.75.75 0 0 1 1.06 0l4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.75.75 0 0 1-1.06-1.06L11.94 10 8.22 6.28a.75.75 0 0 1 0-1.06Z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </:icon>
                </.action_row>
              </div>
            </div>
          <% %Claper.WordClouds.WordCloud{} -> %>
            <div class="space-y-2">
              <.toggle_row
                label={
                  if @state.poll_visible,
                    do: gettext("Hide word cloud on presentation"),
                    else: gettext("Show word cloud on presentation")
                }
                checked={@state.poll_visible}
                key={:poll_visible}
                shortcut={if @create == nil, do: "Z", else: nil}
                show_shortcut={@show_shortcut}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M7 18a4.6 4.4 0 0 1 0 -9a5 4.5 0 0 1 11 2h1a3.5 3.5 0 0 1 0 7h-12" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.layout_settings state={@state} />

              <.toggle_row
                label={
                  if @current_interaction.show_results,
                    do: gettext("Hide live cloud on attendee devices"),
                    else: gettext("Show live cloud on attendee devices")
                }
                checked={@current_interaction.show_results}
                key={:word_cloud_show_results}
                show_shortcut={false}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M6 5a2 2 0 0 1 2 -2h8a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2z" /><path d="M11 4h2" /><path d="M12 17v.01" />
                  </svg>
                </:icon>
              </.toggle_row>

              <div class="rounded-2xl border border-gray-200 bg-white px-3 py-2">
                <div class="flex items-center justify-between gap-2">
                  <span class="text-xs font-semibold text-gray-700">
                    {ngettext("%{count} answer", "%{count} answers", @current_interaction.total || 0)}
                  </span>
                  <button
                    :if={(@current_interaction.total || 0) > 0}
                    type="button"
                    phx-click="word-cloud-reset"
                    phx-value-id={@current_interaction.id}
                    data-confirm={
                      gettext("This will delete every answer of this word cloud, are you sure?")
                    }
                    class="text-xs font-semibold text-supporting-red-500 hover:underline"
                  >
                    {gettext("Reset")}
                  </button>
                </div>

                <div
                  :if={(@current_interaction.words || []) != []}
                  class="mt-2 flex max-h-40 flex-wrap gap-1 overflow-y-auto"
                  data-word-cloud-words
                >
                  <span
                    :for={word <- @current_interaction.words}
                    class="inline-flex items-center gap-1 rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-700"
                  >
                    <span class="font-semibold">{word.text}</span>
                    <span class="text-gray-400">{word.count}</span>
                    <button
                      type="button"
                      phx-click="word-cloud-delete-word"
                      phx-value-id={@current_interaction.id}
                      phx-value-text={word.text}
                      aria-label={gettext("Remove %{word}", word: word.text)}
                      title={gettext("Remove %{word}", word: word.text)}
                      class="ml-0.5 text-gray-400 hover:text-supporting-red-500"
                    >
                      &times;
                    </button>
                  </span>
                </div>
              </div>

              <div
                :if={@current_interaction.moderation_enabled}
                class="rounded-2xl border border-gray-200 bg-white px-3 py-2"
                data-word-cloud-moderation
              >
                <p class="text-xs font-semibold text-gray-700">
                  {gettext("Moderation")}
                  <span
                    :if={(@current_interaction.pending_count || 0) > 0}
                    class="badge badge-sm badge-primary ml-1"
                  >
                    {@current_interaction.pending_count}
                  </span>
                </p>
                <p
                  :if={(@current_interaction.pending_count || 0) == 0}
                  class="mt-1 text-xs italic text-gray-400"
                >
                  {gettext("No answer waiting for approval")}
                </p>
                <ul
                  :if={(@current_interaction.pending_count || 0) > 0}
                  class="mt-2 max-h-48 space-y-1 overflow-y-auto"
                >
                  <li
                    :for={
                      response <- Claper.WordClouds.list_responses(@current_interaction.id, "pending")
                    }
                    class="flex items-center justify-between gap-2 rounded-lg bg-gray-50 px-2 py-1"
                    data-pending-response={response.id}
                  >
                    <span class="truncate text-sm text-gray-800">{response.original_text}</span>
                    <span class="flex shrink-0 gap-1">
                      <button
                        type="button"
                        phx-click="word-cloud-moderate"
                        phx-value-id={response.id}
                        phx-value-status="approved"
                        class="btn btn-xs btn-primary"
                      >
                        {gettext("Approve")}
                      </button>
                      <button
                        type="button"
                        phx-click="word-cloud-moderate"
                        phx-value-id={response.id}
                        phx-value-status="rejected"
                        class="btn btn-xs btn-outline btn-error"
                      >
                        {gettext("Reject")}
                      </button>
                    </span>
                  </li>
                </ul>
              </div>
            </div>
          <% %Claper.OpenEnded.OpenEnded{} -> %>
            <div class="space-y-2">
              <.toggle_row
                label={
                  if @state.poll_visible,
                    do: gettext("Hide responses on presentation"),
                    else: gettext("Show responses on presentation")
                }
                checked={@state.poll_visible}
                key={:poll_visible}
                shortcut={if @create == nil, do: "Z", else: nil}
                show_shortcut={@show_shortcut}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h8" /><path d="M8 13h6" /><path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12z" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.layout_settings state={@state} />

              <.toggle_row
                label={gettext("Vote on responses")}
                checked={@current_interaction.voting_enabled}
                key={:open_ended_voting}
                show_shortcut={false}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M7 11v8a1 1 0 0 1 -1 1h-2a1 1 0 0 1 -1 -1v-7a1 1 0 0 1 1 -1h3a4 4 0 0 0 4 -4v-1a2 2 0 0 1 4 0v5h3a2 2 0 0 1 2 2l-1 5a2 3 0 0 1 -2 2h-7a3 3 0 0 1 -3 -3" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.toggle_row
                label={gettext("Auto-scroll to new responses")}
                checked={@current_interaction.auto_scroll}
                key={:open_ended_auto_scroll}
                show_shortcut={false}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M12 5l0 14" /><path d="M18 13l-6 6" /><path d="M6 13l6 6" />
                  </svg>
                </:icon>
              </.toggle_row>

              <.toggle_row
                label={
                  if @current_interaction.show_results,
                    do: gettext("Hide responses on attendee devices"),
                    else: gettext("Show responses on attendee devices")
                }
                checked={@current_interaction.show_results}
                key={:open_ended_show_results}
                show_shortcut={false}
              >
                <:icon>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="h-5 w-5"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M6 5a2 2 0 0 1 2 -2h8a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2z" /><path d="M11 4h2" /><path d="M12 17v.01" />
                  </svg>
                </:icon>
              </.toggle_row>

              <div class="rounded-2xl border border-gray-200 bg-white px-3 py-2">
                <div class="flex items-center justify-between gap-2">
                  <span class="text-xs font-semibold text-gray-700">
                    {ngettext(
                      "%{count} response",
                      "%{count} responses",
                      @current_interaction.total || 0
                    )}
                  </span>
                  <button
                    :if={(@current_interaction.total || 0) > 0}
                    type="button"
                    phx-click="open-ended-reset"
                    phx-value-id={@current_interaction.id}
                    data-confirm={
                      gettext("This will delete every response of this question, are you sure?")
                    }
                    class="text-xs font-semibold text-supporting-red-500 hover:underline"
                  >
                    {gettext("Reset")}
                  </button>
                </div>

                <ul
                  :if={(@current_interaction.responses || []) != []}
                  class="mt-2 flex max-h-40 flex-col gap-1 overflow-y-auto"
                  data-open-ended-responses
                >
                  <li
                    :for={response <- @current_interaction.responses}
                    class="flex items-start justify-between gap-2 rounded-lg bg-gray-50 px-2 py-1 text-xs text-gray-700"
                    data-open-ended-response={response.id}
                  >
                    <span class="min-w-0 flex-1 break-words">
                      {response.text}
                      <span :if={response.vote_count > 0} class="text-gray-400">
                        · 👍 {response.vote_count}
                      </span>
                    </span>
                    <button
                      type="button"
                      phx-click="open-ended-delete-response"
                      phx-value-id={response.id}
                      aria-label={gettext("Remove response")}
                      title={gettext("Remove response")}
                      class="shrink-0 text-gray-400 hover:text-supporting-red-500"
                    >
                      &times;
                    </button>
                  </li>
                </ul>
              </div>

              <div
                :if={@current_interaction.moderation_enabled}
                class="rounded-2xl border border-gray-200 bg-white px-3 py-2"
                data-open-ended-moderation
              >
                <p class="text-xs font-semibold text-gray-700">
                  {gettext("Moderation")}
                  <span
                    :if={(@current_interaction.pending_count || 0) > 0}
                    class="badge badge-sm badge-primary ml-1"
                  >
                    {@current_interaction.pending_count}
                  </span>
                </p>
                <p
                  :if={(@current_interaction.pending_count || 0) == 0}
                  class="mt-1 text-xs italic text-gray-400"
                >
                  {gettext("No response waiting for approval")}
                </p>
                <ul
                  :if={(@current_interaction.pending_count || 0) > 0}
                  class="mt-2 max-h-48 space-y-1 overflow-y-auto"
                >
                  <li
                    :for={response <- @current_interaction.pending_responses || []}
                    class="flex items-start justify-between gap-2 rounded-lg bg-gray-50 px-2 py-1"
                    data-open-ended-pending={response.id}
                  >
                    <span class="min-w-0 flex-1 break-words text-sm text-gray-800">
                      {response.text}
                    </span>
                    <span class="flex shrink-0 gap-1">
                      <button
                        type="button"
                        phx-click="open-ended-moderate"
                        phx-value-id={response.id}
                        phx-value-status="approved"
                        class="btn btn-xs btn-primary"
                      >
                        {gettext("Approve")}
                      </button>
                      <button
                        type="button"
                        phx-click="open-ended-moderate"
                        phx-value-id={response.id}
                        phx-value-status="rejected"
                        class="btn btn-xs btn-outline btn-error"
                      >
                        {gettext("Reject")}
                      </button>
                    </span>
                  </li>
                </ul>
              </div>
            </div>
          <% nil -> %>
            <p class="text-gray-400 italic mt-1.5 text-sm">{gettext("No interaction enabled")}</p>
          <% _ -> %>
            <p class="text-gray-400 italic mt-1.5 text-sm">
              {gettext("No settings available for this interaction")}
            </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp poll_total(%{poll_opts: opts}) when is_list(opts),
    do: opts |> Enum.map(&(&1.vote_count || 0)) |> Enum.sum()

  defp poll_total(_), do: 0

  attr :state, :map, required: true

  @doc false
  def layout_settings(assigns) do
    alias Claper.Presentations.PresentationState

    assigns =
      assigns
      |> assign(:layout, assigns.state.poll_layout || "overlay")
      |> assign(:size, assigns.state.poll_size || 40)
      |> assign(:corner, assigns.state.poll_corner || "bottom-right")
      |> assign(:min_size, PresentationState.min_size())
      |> assign(:max_size, PresentationState.max_size())

    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white px-3 py-2" data-poll-layout>
      <p class="text-xs font-semibold text-gray-700">{gettext("Position on presentation")}</p>
      <div class="mt-2 grid grid-cols-4 gap-1">
        <.layout_button layout="overlay" current={@layout} label={gettext("Full screen")}>
          <rect x="3" y="4" width="18" height="16" rx="2" />
        </.layout_button>
        <.layout_button layout="side" current={@layout} label={gettext("Side panel")}>
          <rect x="3" y="4" width="18" height="16" rx="2" /><path d="M14 4v16" /><rect
            x="14"
            y="4"
            width="7"
            height="16"
            fill="currentColor"
          />
        </.layout_button>
        <.layout_button layout="corner" current={@layout} label={gettext("Corner box")}>
          <rect x="3" y="4" width="18" height="16" rx="2" /><rect
            x="12"
            y="11"
            width="8"
            height="8"
            fill="currentColor"
          />
        </.layout_button>
        <.layout_button layout="bottom" current={@layout} label={gettext("Bottom bar")}>
          <rect x="3" y="4" width="18" height="16" rx="2" /><path d="M3 14h18" /><rect
            x="3"
            y="14"
            width="18"
            height="6"
            fill="currentColor"
          />
        </.layout_button>
      </div>

      <form
        :if={@layout != "overlay"}
        phx-change="poll-size"
        class="mt-2 flex items-center gap-2"
        data-poll-size
      >
        <span class="text-xs text-gray-600 shrink-0">{gettext("Size")}</span>
        <input
          aria-label={gettext("Size")}
          type="range"
          name="size"
          min={@min_size}
          max={@max_size}
          step="5"
          value={@size}
          phx-debounce="150"
          class="range range-xs range-primary flex-1"
        />
        <span class="text-xs font-semibold text-gray-700 w-9 text-right">{@size}%</span>
      </form>

      <div :if={@layout == "corner"} class="mt-2 grid grid-cols-4 gap-1" data-poll-corner>
        <button
          :for={
            {corner, label} <- [
              {"top-left", gettext("Top left")},
              {"top-right", gettext("Top right")},
              {"bottom-left", gettext("Bottom left")},
              {"bottom-right", gettext("Bottom right")}
            ]
          }
          type="button"
          phx-click="poll-corner"
          phx-value-corner={corner}
          title={label}
          aria-label={label}
          aria-pressed={@corner == corner}
          class={[
            "flex items-center justify-center rounded-lg border py-1 text-[10px] font-medium",
            if(@corner == corner,
              do: "border-primary bg-[#f3defa] text-primary-500",
              else: "border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
            )
          ]}
        >
          {label}
        </button>
      </div>
    </div>
    """
  end

  attr :layout, :string, required: true
  attr :current, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp layout_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="poll-layout"
      phx-value-layout={@layout}
      title={@label}
      aria-label={@label}
      aria-pressed={@current == @layout}
      class={[
        "flex flex-col items-center gap-0.5 rounded-lg border py-1 text-[10px] font-medium",
        if(@current == @layout,
          do: "border-primary bg-[#f3defa] text-primary-500",
          else: "border-gray-200 bg-white text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="h-5 w-5"
      >
        {render_slot(@inner_block)}
      </svg>
      {@label}
    </button>
    """
  end

  attr :label, :string, required: true
  attr :checked, :boolean, required: true
  attr :key, :atom, required: true
  attr :shortcut, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :show_shortcut, :boolean, default: true
  slot :icon, required: true

  defp toggle_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2 rounded-full pl-2 pr-3 py-2 overflow-hidden transition-colors",
      if(@disabled, do: "opacity-50"),
      if(@checked,
        do: "bg-[#f3defa] border-b-2 border-primary",
        else: "bg-white border border-gray-200"
      )
    ]}>
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-full shrink-0",
        if(@checked, do: "bg-white text-primary-500", else: "bg-gray-100 text-secondary-500")
      ]}>
        {render_slot(@icon)}
      </div>
      <span class={["flex-1 text-xs text-gray-700", if(@checked, do: "font-semibold")]}>
        {@label}
      </span>
      <div class="flex items-center gap-x-2 shrink-0">
        <kbd :if={@show_shortcut && @shortcut} class="kbd kbd-sm">
          {@shortcut}
        </kbd>
        <button
          phx-click={ClaperWeb.Component.Input.checked(@checked, @key)}
          disabled={@disabled}
          phx-value-key={@key}
          type="button"
          class={"relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none disabled:cursor-not-allowed #{if @checked, do: "bg-primary-500", else: "bg-gray-200"}"}
          role="switch"
          aria-checked={@checked}
          phx-key={@shortcut}
          phx-window-keydown={
            if @shortcut && not @disabled, do: ClaperWeb.Component.Input.checked(@checked, @key)
          }
        >
          <span class={"pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out #{if @checked, do: "translate-x-5", else: "translate-x-0"}"}>
          </span>
        </button>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :key, :atom, required: true
  attr :disabled, :boolean, default: false
  attr :compact, :boolean, default: false
  attr :reverse, :boolean, default: false
  slot :icon, required: true

  defp action_row(assigns) do
    ~H"""
    <button
      phx-click={ClaperWeb.Component.Input.checked(false, @key)}
      phx-value-key={@key}
      type="button"
      disabled={@disabled}
      class={[
        "w-full flex items-center rounded-full border border-gray-200 bg-white text-left transition-colors",
        if(@compact, do: "px-1 py-2", else: "gap-3 pl-2 pr-3 py-2"),
        if(@reverse, do: "flex-row-reverse"),
        if(@disabled, do: "opacity-50 cursor-not-allowed", else: "hover:bg-primary-50")
      ]}
    >
      <div class="flex items-center justify-center w-8 h-8 rounded-full shrink-0 bg-gray-100 text-secondary-500">
        {render_slot(@icon)}
      </div>
      <span class={[
        "text-xs text-gray-700",
        if(@compact, do: "flex-1 text-center font-medium", else: "flex-1")
      ]}>
        {@label}
      </span>
    </button>
    """
  end
end
