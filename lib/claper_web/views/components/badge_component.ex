defmodule ClaperWeb.Component.Badge do
  @moduledoc """
  DaisyUI-inspired Badge component for Claper.

  ## Types
  - `:contained` - Filled background (default)
  - `:outlined` - Border only, transparent background

  ## Styles
  - `:default` - Gray background/border (default)
  - `:neutral` - Dark background, white text
  - `:primary` - Purple theme color
  - `:secondary` - Navy purple theme color
  - `:accent` - Cyan/teal accent color
  - `:ghost` - Transparent, subtle text

  ## Sizes
  - `:xs` - Extra small (default)
  - `:sm` - Small
  - `:md` - Medium
  - `:lg` - Large

  ## Examples

      <.badge>Default</.badge>
      <.badge style={:primary}>Primary</.badge>
      <.badge type={:outlined} style={:primary}>Outlined</.badge>
      <.badge size={:lg} style={:accent}>Large Accent</.badge>
  """
  use ClaperWeb, :view_component

  attr :type, :atom, default: :contained, values: [:contained, :outlined]

  attr :style, :atom,
    default: :default,
    values: [:default, :neutral, :primary, :secondary, :accent, :ghost]

  attr :size, :atom, default: :xs, values: [:xs, :sm, :md, :lg]
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        base_classes(),
        size_classes(@size),
        style_classes(@type, @style),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  # Base classes for all badges
  defp base_classes do
    "inline-flex items-center justify-center font-normal font-display rounded-lg whitespace-nowrap"
  end

  # Size classes
  defp size_classes(:xs), do: "px-2 py-0.5 text-xs leading-4"
  defp size_classes(:sm), do: "px-3 py-0.5 text-xs leading-4"
  defp size_classes(:md), do: "px-3 py-1 text-sm leading-5"
  defp size_classes(:lg), do: "px-4 py-1.5 text-base leading-6"

  # Style classes for contained type
  defp style_classes(:contained, :default) do
    "bg-gray-200 text-gray-700"
  end

  defp style_classes(:contained, :neutral) do
    "bg-neutral-800 text-neutral-50"
  end

  defp style_classes(:contained, :primary) do
    "bg-primary-500 text-white"
  end

  defp style_classes(:contained, :secondary) do
    "bg-secondary-500 text-white"
  end

  defp style_classes(:contained, :accent) do
    "bg-supporting-green-400 text-supporting-green-900"
  end

  defp style_classes(:contained, :ghost) do
    "bg-gray-100 text-gray-700"
  end

  # Style classes for outlined type
  defp style_classes(:outlined, :default) do
    "bg-transparent border border-gray-300 text-gray-700"
  end

  defp style_classes(:outlined, :neutral) do
    "bg-transparent border border-neutral-800 text-neutral-800"
  end

  defp style_classes(:outlined, :primary) do
    "bg-transparent border border-primary-500 text-primary-500"
  end

  defp style_classes(:outlined, :secondary) do
    "bg-transparent border border-secondary-500 text-secondary-500"
  end

  defp style_classes(:outlined, :accent) do
    "bg-transparent border border-supporting-green-500 text-supporting-green-500"
  end

  defp style_classes(:outlined, :ghost) do
    "bg-transparent border border-gray-200 text-gray-600"
  end
end
