defmodule ClaperWeb.EventLive.WordCloudCloudComponent do
  @moduledoc """
  Function component that renders the cloud itself. The layout is computed in
  the browser by the `WordCloud` JS hook from the `data-words` attribute, so
  the same component serves the presenter screen, the manager preview and the
  attendee phone.
  """
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  attr :id, :string, required: true
  attr :words, :list, required: true
  attr :class, :string, default: nil
  attr :min_size, :integer, default: nil
  attr :max_size, :integer, default: nil
  attr :empty, :string, default: nil

  def cloud(assigns) do
    assigns =
      assigns
      |> assign_new(:empty_text, fn -> assigns.empty || gettext("Waiting for answers...") end)
      |> assign(
        :words_json,
        Jason.encode!(Enum.map(assigns.words, &Map.take(&1, [:text, :count])))
      )

    ~H"""
    <div
      id={@id}
      phx-hook="WordCloud"
      phx-update="ignore"
      data-words={@words_json}
      data-min-size={@min_size}
      data-max-size={@max_size}
      data-empty={@empty_text}
      class={["relative w-full overflow-hidden select-none", @class]}
      aria-live="polite"
    >
    </div>
    """
  end
end
