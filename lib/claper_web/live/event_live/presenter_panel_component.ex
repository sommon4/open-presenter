defmodule ClaperWeb.EventLive.PresenterPanelComponent do
  @moduledoc """
  Container for an interaction (poll, word cloud, open ended...) on the
  presenter screen.

  The presentation state decides where the panel goes:

    * `overlay` — full screen on top of the slide (historical behaviour)
    * `side`    — a column on the right, the slide keeps the rest of the width
    * `bottom`  — a bar under the slide
    * `corner`  — a small box in one corner, on top of the slide

  `poll_size` is a percentage of the screen (width for side/corner, height
  for bottom).
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :state, :map, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def panel(assigns) do
    layout = layout(assigns.state)
    size = size(assigns.state)

    assigns =
      assigns
      |> assign(:layout, layout)
      |> assign(:size, size)
      |> assign(:visible, assigns.state.poll_visible)
      |> assign(:corner, corner(assigns.state))

    ~H"""
    <div
      id={@id}
      data-layout={@layout}
      class={[
        "absolute z-30 flex flex-col transition-opacity overflow-hidden",
        if(@visible, do: "opacity-100", else: "opacity-0 pointer-events-none"),
        layout_class(@layout, @corner),
        @class
      ]}
      style={layout_style(@layout, @size)}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Data attributes for `#presenter` so CSS can make room for the panel."
  def presenter_attrs(state) do
    layout = layout(state)
    size = size(state)

    %{
      "data-poll-layout" => if(state.poll_visible, do: layout, else: "overlay"),
      "style" => "--poll-size: #{size}%; --poll-size-vh: #{size}vh;"
    }
  end

  @doc "True when the panel is small, so text must be smaller too."
  def compact?(state, iframe), do: iframe || layout(state) != "overlay"

  def layout(%{poll_layout: l}) when l in ["overlay", "side", "corner", "bottom"], do: l
  def layout(_), do: "overlay"

  def size(%{poll_size: s}) when is_integer(s) and s >= 15 and s <= 75, do: s
  def size(_), do: 40

  def corner(%{poll_corner: c})
      when c in ["top-left", "top-right", "bottom-left", "bottom-right"],
      do: c

  def corner(_), do: "bottom-right"

  defp layout_class("overlay", _),
    do:
      "h-full w-full bg-black/90 left-1/2 top-1/2 transform -translate-y-1/2 -translate-x-1/2 p-10"

  defp layout_class("side", _),
    do: "top-0 right-0 h-full bg-black/90 p-6 border-l border-white/20"

  defp layout_class("bottom", _),
    do: "bottom-0 left-0 w-full bg-black/90 p-4 border-t border-white/20"

  defp layout_class("corner", corner),
    do: "bg-black/85 rounded-2xl p-4 shadow-2xl border border-white/20 " <> corner_class(corner)

  defp corner_class("top-left"), do: "top-4 left-4"
  defp corner_class("top-right"), do: "top-4 right-4"
  defp corner_class("bottom-left"), do: "bottom-4 left-4"
  defp corner_class(_), do: "bottom-4 right-4"

  defp layout_style("side", size), do: "width: #{size}%;"
  defp layout_style("bottom", size), do: "height: #{size}vh;"
  defp layout_style("corner", size), do: "width: #{size}%; max-height: 80vh;"
  defp layout_style(_, _), do: nil
end
