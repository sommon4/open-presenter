defmodule ClaperWeb.Component.Select do
  @moduledoc """
  DaisyUI select field for Claper forms.

  Wraps the daisyUI [`select`](https://daisyui.com/components/select/) component
  (pill-shaped and `!font-display` via `assets/css/app.css`) together with a bold
  field label and inline validation errors. Form-aware: pass a
  `Phoenix.HTML.Form`, the field `key` and the `options`.

  `options` accepts anything
  [`options_for_select/2`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2)
  understands, e.g. `[{"Text", "text"}, {"Email", "email"}]`.

  ## Sizes
  - `:sm` - 40px height
  - `:md` - 48px height (default)
  - `:lg` - 56px height

  ## Examples

      <.select_field
        form={i}
        key={:type}
        label={gettext("Type")}
        options={[{gettext("Text"), "text"}, {gettext("Email"), "email"}]}
      />
  """
  use ClaperWeb, :view_component

  attr :form, Phoenix.HTML.Form, required: true
  attr :key, :atom, required: true
  attr :options, :list, required: true
  attr :label, :string, default: nil
  attr :prompt, :string, default: nil
  attr :required, :boolean, default: false
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled multiple phx-change)

  def select_field(assigns) do
    assigns = assign_new(assigns, :errors, fn -> error_tag(assigns.form, assigns.key) end)

    ~H"""
    <div class="flex flex-col gap-1">
      <label :if={@label} for={input_id(@form, @key)} class="text-sm font-bold text-base-content">
        {@label}
      </label>
      <select
        name={input_name(@form, @key)}
        id={input_id(@form, @key)}
        required={@required}
        class={[
          "select w-full bg-white",
          size_class(@size),
          @errors != [] && "select-error",
          @class
        ]}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, input_value(@form, @key))}
      </select>
      <p :if={@errors != []} class="text-supporting-red-500 text-sm">{@errors}</p>
    </div>
    """
  end

  defp size_class(:sm), do: "h-10"
  defp size_class(:md), do: "h-12"
  defp size_class(:lg), do: "h-14"
end
