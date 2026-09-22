defmodule ClaperWeb.EventLive.ManageSlideSidebarComponent do
  use ClaperWeb, :live_component

  alias Claper.Presentations

  def render(assigns) do
    thumbnail_urls =
      assigns.presentation_file
      |> Presentations.get_slide_thumbnail_urls()
      |> Enum.map(&append_cache_bust(&1, assigns.thumbnail_cache_bust))

    assigns = assign(assigns, :thumbnail_urls, thumbnail_urls)

    ~H"""
    <div class="flex flex-col h-full bg-gray-100 rounded-r-2xl px-4">
      <div class="px-4 py-3 flex items-center gap-x-2">
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
          class="icon icon-tabler icons-tabler-outline icon-tabler-presentation shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M3 4l18 0" />
          <path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" />
          <path d="M12 16l0 4" />
          <path d="M9 20l6 0" />
          <path d="M8 12l3 -3l2 2l3 -3" />
        </svg>

        <span class="font-bold text-sm text-[#140553]">{gettext("Content")}</span>
      </div>
      <div id="slide-sortable" phx-hook="SlideSortable" class="flex-1 overflow-y-auto p-3 space-y-2">
        <button
          :for={{src, index} <- @thumbnail_urls |> Enum.with_index(0)}
          id={"slide-thumb-#{index}"}
          draggable="true"
          data-index={index}
          phx-click="current-page"
          phx-value-page={index}
          class={"group flex items-start gap-x-1.5 w-full rounded-lg p-1 transition-all cursor-grab active:cursor-grabbing hover:bg-gray-200 #{if @current_position == index, do: "bg-primary-50"}"}
        >
          <span class={"flex-shrink-0 w-5 text-base font-semibold #{if @current_position == index, do: "text-primary-600", else: "text-gray-500"}"}>
            {index + 1}
          </span>
          <div class={"relative w-28 aspect-video rounded-md overflow-hidden border-2 transition-all #{if @current_position == index, do: "border-primary-500 shadow-md", else: "border-transparent opacity-60 group-hover:opacity-100"}"}>
            <img
              src={src}
              draggable="false"
              loading="lazy"
              decoding="async"
              class="w-full h-full object-cover"
              alt={"Slide #{index + 1}"}
            />
          </div>
        </button>
      </div>
    </div>
    """
  end

  defp append_cache_bust(url, nil), do: url
  defp append_cache_bust(url, cache_bust), do: "#{url}?v=#{cache_bust}"
end
