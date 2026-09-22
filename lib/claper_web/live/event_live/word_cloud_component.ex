defmodule ClaperWeb.EventLive.WordCloudComponent do
  @moduledoc """
  Attendee view of a Word Cloud: the question, an answer box, the attendee's
  own answers and, when the presenter allows it, the live cloud.
  """
  use ClaperWeb, :live_component

  import ClaperWeb.EventLive.WordCloudCloudComponent

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:focus_mode, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> assign(:remaining, max(assigns.word_cloud.max_answers - length(assigns.responses), 0))

    ~H"""
    <div class="font-display">
      <div
        id="extended-word-cloud"
        class={[
          "w-full rounded-2xl bg-gray-900 p-4 text-gray-100",
          @focus_mode && "shadow-none ring-0",
          !@focus_mode && "shadow-2xl ring-1 ring-white/10"
        ]}
      >
        <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Word cloud")}</p>
        <p class="mb-3 text-lg font-bold leading-snug text-white">{@word_cloud.title}</p>

        <div :if={@responses != []} class="mb-3 flex flex-wrap gap-2" id="word-cloud-my-answers">
          <span
            :for={response <- @responses}
            class={[
              "rounded-full px-3 py-1 text-sm font-semibold",
              response.status == "pending" && "bg-gray-700 text-gray-300",
              response.status != "pending" && "bg-primary-900/60 text-primary-100"
            ]}
            title={if response.status == "pending", do: gettext("Waiting for approval")}
          >
            {response.original_text}
            <span :if={response.status == "pending"} class="ml-1 text-xs text-gray-400">
              ({gettext("pending")})
            </span>
          </span>
        </div>

        <%= if @remaining > 0 do %>
          <form
            id={"word-cloud-form-#{@word_cloud.id}-#{length(@responses)}"}
            phx-submit="submit-word"
            class="flex flex-col gap-2"
            autocomplete="off"
          >
            <input
              type="text"
              name="word"
              id={"word-cloud-input-#{@word_cloud.id}"}
              maxlength={@word_cloud.max_characters}
              placeholder={gettext("Type your answer...")}
              class="w-full rounded-xl border border-gray-700 bg-gray-800 px-3 py-2 text-sm font-semibold text-white placeholder:text-gray-500 focus:border-primary-400 focus:outline-none"
              autofocus
              required
            />
            <p :if={@error} class="text-sm text-supporting-red-400" role="alert">{@error}</p>
            <div class="flex items-center justify-between gap-2">
              <span class="text-xs text-gray-400">
                {ngettext("%{count} answer left", "%{count} answers left", @remaining)}
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
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <path d="M5 12l5 5l10 -10" />
            </svg>
            {gettext("Thank you!")}
          </button>
        <% end %>

        <div :if={@word_cloud.show_results} class="mt-4">
          <.cloud
            id={"attendee-word-cloud-#{@word_cloud.id}"}
            words={@word_cloud.words || []}
            class="h-40 rounded-xl bg-gray-800/60 text-white"
            min_size={12}
            max_size={30}
          />
        </div>
      </div>
    </div>
    """
  end
end
