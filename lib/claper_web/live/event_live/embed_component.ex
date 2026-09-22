defmodule ClaperWeb.EventLive.EmbedComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :focus_mode, fn -> false end)

    ~H"""
    <div class="font-display">
      <div
        :if={!@focus_mode}
        id="collapsed-embed"
        class="mx-auto hidden w-max rounded-full bg-gray-900 px-5 py-3 shadow-xl ring-1 ring-white/10"
      >
        <button
          type="button"
          class="block h-full w-full cursor-pointer"
          phx-click={toggle_embed()}
          phx-target={@myself}
        >
          <div class="flex items-center gap-2 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="h-5 w-5 text-primary-300"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
              />
            </svg>
            <span class="text-sm font-bold">{gettext("See current web content")}</span>
          </div>
        </button>
      </div>
      <div
        id="extended-embed"
        class={[
          "w-full rounded-2xl bg-gray-900 p-4 text-gray-100",
          @focus_mode && "shadow-none ring-0",
          !@focus_mode && "shadow-2xl ring-1 ring-white/10"
        ]}
      >
        <div class="relative pr-8">
          <button
            :if={!@focus_mode}
            id="embed-pane"
            type="button"
            aria-label={gettext("Close")}
            class="absolute -right-1 -top-1 grid h-8 w-8 place-items-center rounded-full text-gray-400 transition-colors hover:bg-white/10 hover:text-white"
            phx-click={toggle_embed()}
            phx-target={@myself}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Current web content")}</p>
          <p class="mb-4 text-lg font-bold leading-snug text-white">{@embed.title}</p>
        </div>
        <div class={[
          "w-full rounded-xl",
          @embed.provider == "custom" && "overflow-x-auto",
          @embed.provider != "custom" && "aspect-video overflow-hidden bg-black"
        ]}>
          <.live_component
            id="embed-component"
            module={ClaperWeb.EventLive.EmbedIframeComponent}
            provider={@embed.provider}
            content={@embed.content}
            title={@embed.title}
          />
        </div>
      </div>
    </div>
    """
  end

  def toggle_embed(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-embed",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-embed"
    )
  end
end
