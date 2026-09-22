defmodule ClaperWeb.Component.TextInput do
  @moduledoc """
  DaisyUI text input field for Claper forms.

  Wraps the daisyUI [`input`](https://daisyui.com/components/input/) component
  (pill-shaped and `!font-display` via `assets/css/app.css`) together with a bold
  field label and inline validation errors. The component is form-aware: pass a
  `Phoenix.HTML.Form` and the field `key` and it derives the name, id, value and
  errors — including for nested forms built with `inputs_for/3`.

  ## Sizes
  - `:sm` - 40px height
  - `:md` - 48px height (default)
  - `:lg` - 56px height

  ## Examples

      <.text_field form={f} key={:title} label={gettext("Poll's title")} required />

      <.text_field form={f} key={:email} type="email" placeholder="you@example.com" />

      <.text_field form={i} key={:content} label={gettext("Choice")} required>
        <:trailing>
          <.icon_button style={:ghost} shape={:circle} size={:sm}>…</.icon_button>
        </:trailing>
      </.text_field>
  """
  use ClaperWeb, :view_component

  attr :form, Phoenix.HTML.Form, required: true
  attr :key, :atom, required: true

  attr :type, :string,
    default: "text",
    values: ~w(text email url tel search password number)

  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :autofocus, :boolean, default: false
  attr :autocomplete, :string, default: nil
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :minlength, :any, default: nil
  attr :maxlength, :any, default: nil
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(phx-debounce phx-blur inputmode pattern step min max readonly disabled)

  slot :trailing, doc: "content rendered to the right of the input, e.g. a remove button"

  def text_field(assigns) do
    assigns = assign_new(assigns, :errors, fn -> error_tag(assigns.form, assigns.key) end)

    ~H"""
    <div class="flex flex-col gap-1">
      <label :if={@label} for={input_id(@form, @key)} class="text-sm font-bold text-base-content">
        {@label}
      </label>
      <div class="flex items-center gap-2">
        <input
          type={@type}
          name={input_name(@form, @key)}
          id={input_id(@form, @key)}
          value={input_value(@form, @key)}
          placeholder={@placeholder}
          required={@required}
          autofocus={@autofocus}
          autocomplete={@autocomplete}
          minlength={@minlength}
          maxlength={@maxlength}
          class={[
            "input w-full bg-white",
            size_class(@size),
            @errors != [] && "input-error",
            @class
          ]}
          {@rest}
        />
        {render_slot(@trailing)}
      </div>
      <p :if={@errors != []} class="text-supporting-red-500 text-sm">{@errors}</p>
    </div>
    """
  end

  defp size_class(:sm), do: "h-10"
  defp size_class(:md), do: "h-12"
  defp size_class(:lg), do: "h-14"
end
