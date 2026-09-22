defmodule ClaperWeb.EventLive.OpenEndedCardsComponent do
  @moduledoc """
  Function component that renders Open Ended responses as cards, used by the
  presenter screen. With `auto_scroll` the `OpenEndedScroll` JS hook keeps the
  newest card in view.
  """
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  attr :id, :string, required: true
  attr :responses, :list, required: true
  attr :auto_scroll, :boolean, default: false
  attr :voting, :boolean, default: false
  attr :compact, :boolean, default: false
  attr :class, :string, default: nil

  def cards(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="OpenEndedScroll"
      data-auto-scroll={to_string(@auto_scroll)}
      data-count={length(@responses)}
      class={["relative w-full overflow-y-auto", @class]}
      aria-live="polite"
    >
      <p
        :if={@responses == []}
        class="absolute inset-0 flex items-center justify-center text-center text-gray-400"
      >
        {gettext("Waiting for responses...")}
      </p>
      <div class={["grid gap-3", if(@compact, do: "grid-cols-2", else: "grid-cols-2 lg:grid-cols-3")]}>
        <div
          :for={response <- @responses}
          id={"#{@id}-response-#{response.id}"}
          class={[
            "open-ended-card rounded-2xl bg-white/95 text-gray-900 shadow-lg break-words",
            if(@compact, do: "p-3 text-sm", else: "p-5 text-2xl")
          ]}
        >
          <p class="font-semibold leading-snug">{response.text}</p>
          <p
            :if={@voting}
            class={["mt-2 font-bold text-primary-600", if(@compact, do: "text-xs", else: "text-lg")]}
          >
            👍 {response.vote_count}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
