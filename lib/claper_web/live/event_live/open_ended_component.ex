defmodule ClaperWeb.EventLive.OpenEndedComponent do
  @moduledoc """
  Attendee view of an Open Ended question: the question, a response box, the
  attendee's own responses and, when allowed, everyone's responses with
  optional voting.
  """
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:focus_mode, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:voted_ids, fn -> [] end)
      |> assign(
        :can_answer,
        assigns.open_ended.multiple_responses or assigns.responses == []
      )

    ~H"""
    <div class="font-display">
      <div
        id="extended-open-ended"
        class={[
          "w-full rounded-2xl bg-gray-900 p-4 text-gray-100",
          @focus_mode && "shadow-none ring-0",
          !@focus_mode && "shadow-2xl ring-1 ring-white/10"
        ]}
      >
        <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Open ended")}</p>
        <p class="mb-3 text-lg font-bold leading-snug text-white">{@open_ended.title}</p>

        <%= if @can_answer do %>
          <form
            id={"open-ended-form-#{@open_ended.id}-#{length(@responses)}"}
            phx-submit="submit-open-ended"
            class="flex flex-col gap-2"
            autocomplete="off"
          >
            <textarea
              name="text"
              id={"open-ended-input-#{@open_ended.id}"}
              maxlength={@open_ended.max_characters}
              rows="2"
              placeholder={gettext("Type your response...")}
              class="w-full resize-none rounded-xl border border-gray-700 bg-gray-800 px-3 py-2 text-sm font-semibold text-white placeholder:text-gray-500 focus:border-primary-400 focus:outline-none"
              required
            ></textarea>
            <p :if={@error} class="text-sm text-supporting-red-400" role="alert">{@error}</p>
            <div class="flex items-center justify-between gap-2">
              <span class="text-xs text-gray-400">
                {gettext("Up to %{count} characters", count: @open_ended.max_characters)}
              </span>
              <button
                type="submit"
                phx-disable-with="..."
                class="btn-gradient rounded-lg px-4 py-2 text-sm font-bold transition-colors"
              >
                {gettext("Submit")}
              </button>
            </div>
          </form>
        <% else %>
          <button
            type="button"
            disabled
            data-submitted
            class="inline-flex w-full cursor-not-allowed items-center justify-center gap-2 rounded-lg bg-gray-700 px-3 py-2 text-sm font-bold text-gray-400"
          >
            {gettext("Thank you!")}
          </button>
        <% end %>

        <div :if={@responses != []} class="mt-3" id="open-ended-my-responses">
          <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Your responses")}</p>
          <ul class="flex flex-col gap-1">
            <li
              :for={response <- @responses}
              class="rounded-xl bg-primary-900/50 px-3 py-2 text-sm text-primary-100"
            >
              {response.text}
              <span :if={response.status == "pending"} class="ml-1 text-xs text-gray-400">
                ({gettext("pending")})
              </span>
            </li>
          </ul>
        </div>

        <div :if={@open_ended.show_results} class="mt-4" id="open-ended-all-responses">
          <p class="mb-1 text-xs font-semibold text-gray-400">
            {ngettext("%{count} response", "%{count} responses", @open_ended.total || 0)}
          </p>
          <ul class="flex max-h-48 flex-col gap-1 overflow-y-auto">
            <li
              :for={response <- @open_ended.responses || []}
              id={"attendee-response-#{response.id}"}
              class="flex items-start justify-between gap-2 rounded-xl bg-gray-800 px-3 py-2 text-sm text-white"
            >
              <span class="min-w-0 flex-1 break-words">{response.text}</span>
              <button
                :if={@open_ended.voting_enabled}
                type="button"
                phx-click="vote-open-ended"
                phx-value-id={response.id}
                aria-pressed={to_string(response.id in @voted_ids)}
                class={[
                  "flex shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-xs font-bold",
                  response.id in @voted_ids && "bg-primary-500 text-white",
                  response.id not in @voted_ids && "bg-gray-700 text-gray-200"
                ]}
              >
                👍 {response.vote_count}
              </button>
              <span
                :if={!@open_ended.voting_enabled and response.vote_count > 0}
                class="shrink-0 text-xs text-gray-400"
              >
                👍 {response.vote_count}
              </span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
