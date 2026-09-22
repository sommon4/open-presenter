defmodule ClaperWeb.Component.Checkbox do
  @moduledoc """
  DaisyUI checkbox with an inline label for Claper forms.

  Wraps the daisyUI [`checkbox`](https://daisyui.com/components/checkbox/)
  component and renders the hidden fallback input so an unchecked box still
  submits `false` inside a `<.form>` bound to an Ecto changeset. Form-aware: pass
  a `Phoenix.HTML.Form` and the field `key`.

  ## Colors
  - `:primary` - Claper purple (default)
  - `:secondary` - navy purple
  - `:neutral` - grey
  - `:default` - theme default

  ## Sizes
  - `:sm`, `:md` (default), `:lg`

  ## Examples

      <.checkbox form={f} key={:multiple} label={gettext("Multiple answers")} />

      <.checkbox form={f} key={:accept} color={:secondary}>
        {gettext("I accept the")} <a href="/terms" class="link">{gettext("terms")}</a>
      </.checkbox>
  """
  use ClaperWeb, :view_component

  attr :form, Phoenix.HTML.Form, required: true
  attr :key, :atom, required: true
  attr :label, :string, default: nil
  attr :color, :atom, default: :primary, values: [:primary, :secondary, :neutral, :default]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-change disabled)

  slot :inner_block

  def checkbox(assigns) do
    ~H"""
    <label class="flex items-center gap-3 cursor-pointer py-2">
      <input type="hidden" name={input_name(@form, @key)} value="false" disabled={@rest[:disabled]} />
      <input
        type="checkbox"
        name={input_name(@form, @key)}
        id={input_id(@form, @key)}
        value="true"
        checked={Phoenix.HTML.Form.normalize_value("checkbox", input_value(@form, @key))}
        class={["checkbox shrink-0", color_class(@color), size_class(@size), @class]}
        {@rest}
      />
      <span :if={@label} class="text-base text-neutral">{@label}</span>
      {render_slot(@inner_block)}
    </label>
    """
  end

  defp color_class(:primary), do: "checkbox-primary"
  defp color_class(:secondary), do: "checkbox-secondary"
  defp color_class(:neutral), do: "checkbox-neutral"
  defp color_class(:default), do: nil

  defp size_class(:sm), do: "checkbox-sm"
  defp size_class(:md), do: nil
  defp size_class(:lg), do: "checkbox-lg"
end
