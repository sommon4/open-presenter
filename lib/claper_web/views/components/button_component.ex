defmodule ClaperWeb.Component.Button do
  @moduledoc """
  DaisyUI-inspired Button component for Claper.

  ## Styles
  - `:primary` - Purple background, white text (default)
  - `:secondary` - Light background with purple text and border
  - `:neutral` - Dark background, white text
  - `:accent` - Teal/cyan accent color
  - `:ghost` - Transparent background, visible on hover
  - `:default` - Gray background, dark text

  ## Sizes
  - `:xs` - Extra small (24px height)
  - `:sm` - Small (32px height)
  - `:md` - Medium (48px height, default)
  - `:lg` - Large (64px height)

  ## Shapes
  - `:square` - Standard rounded corners (default)
  - `:circle` - Fully rounded (pill shape)

  ## Examples

      <.button>Click me</.button>
      <.button style={:primary} size={:lg}>Large Primary</.button>
      <.button style={:ghost} shape={:circle}>Ghost Pill</.button>
      <.button disabled>Disabled</.button>
  """
  use ClaperWeb, :view_component

  attr :type, :string, default: "button"

  attr :style, :atom,
    default: :primary,
    values: [:primary, :secondary, :neutral, :accent, :ghost, :default]

  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg]
  attr :shape, :atom, default: :square, values: [:square, :circle]
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(phx-click phx-target phx-disable-with phx-value-id form name value)

  slot :inner_block, required: true
  slot :icon_left
  slot :icon_right

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        base_classes(),
        size_classes(@size),
        style_classes(@style),
        shape_classes(@shape, @size),
        disabled_classes(@disabled),
        @class
      ]}
      {@rest}
    >
      <%= if @icon_left != [] do %>
        <span class={icon_size_classes(@size)}>
          {render_slot(@icon_left)}
        </span>
      <% end %>
      <span class="truncate">{render_slot(@inner_block)}</span>
      <%= if @icon_right != [] do %>
        <span class={icon_size_classes(@size)}>
          {render_slot(@icon_right)}
        </span>
      <% end %>
    </button>
    """
  end

  attr :type, :string, default: "button"

  attr :style, :atom,
    default: :default,
    values: [:primary, :secondary, :neutral, :accent, :ghost, :default]

  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg]
  attr :shape, :atom, default: :square, values: [:square, :circle]
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(phx-click phx-target phx-disable-with phx-value-id form name value)

  slot :inner_block, required: true

  def icon_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        base_classes(),
        icon_button_size_classes(@size),
        style_classes(@style),
        icon_button_shape_classes(@shape),
        disabled_classes(@disabled),
        @class
      ]}
      {@rest}
    >
      <span class={icon_size_classes(@size)}>
        {render_slot(@inner_block)}
      </span>
    </button>
    """
  end

  # Base classes for all buttons
  defp base_classes do
    "inline-flex items-center justify-center gap-2 font-bold font-display transition-all duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-offset-2 whitespace-nowrap"
  end

  # Size classes
  defp size_classes(:xs), do: "h-6 px-2.5 text-xs"
  defp size_classes(:sm), do: "h-8 px-3.5 text-sm"
  defp size_classes(:md), do: "h-12 px-4 text-base"
  defp size_classes(:lg), do: "h-16 px-6 text-base"

  # Icon button size classes (square dimensions)
  defp icon_button_size_classes(:xs), do: "size-6"
  defp icon_button_size_classes(:sm), do: "size-8"
  defp icon_button_size_classes(:md), do: "size-12"
  defp icon_button_size_classes(:lg), do: "size-16"

  # Icon size classes
  defp icon_size_classes(:xs), do: "size-4 shrink-0"
  defp icon_size_classes(:sm), do: "size-[18px] shrink-0"
  defp icon_size_classes(:md), do: "size-5 shrink-0"
  defp icon_size_classes(:lg), do: "size-6 shrink-0"

  # Style classes
  defp style_classes(:primary) do
    "bg-primary-500 text-white hover:bg-primary-600 active:bg-primary-700 focus:ring-primary-500"
  end

  defp style_classes(:secondary) do
    "bg-primary-50 text-secondary-500 border border-primary-200 hover:bg-primary-100 active:bg-primary-200 focus:ring-primary-500"
  end

  defp style_classes(:neutral) do
    "bg-neutral-800 text-white hover:bg-neutral-900 active:bg-neutral-700 focus:ring-neutral-500"
  end

  defp style_classes(:accent) do
    "bg-supporting-green-500 text-white hover:bg-supporting-green-600 active:bg-supporting-green-700 focus:ring-supporting-green-500"
  end

  defp style_classes(:ghost) do
    "bg-transparent text-gray-700 hover:bg-gray-100 active:bg-gray-200 focus:ring-gray-500"
  end

  defp style_classes(:default) do
    "bg-gray-200 text-gray-800 hover:bg-gray-300 active:bg-gray-400 focus:ring-gray-500"
  end

  # Shape classes
  defp shape_classes(:square, _size), do: "rounded-lg"
  defp shape_classes(:circle, _size), do: "rounded-full"

  # Icon button shape classes
  defp icon_button_shape_classes(:square), do: "rounded-lg"
  defp icon_button_shape_classes(:circle), do: "rounded-full"

  # Disabled classes
  defp disabled_classes(true), do: "opacity-50 cursor-not-allowed pointer-events-none"
  defp disabled_classes(false), do: "cursor-pointer"
end
