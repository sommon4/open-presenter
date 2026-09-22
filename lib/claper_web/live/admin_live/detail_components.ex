defmodule ClaperWeb.AdminLive.DetailComponents do
  @moduledoc """
  Shared presentation components and formatting helpers for the
  admin show pages (audit logs, users, events).

  These components encapsulate the labeled-row "details card" pattern so
  every admin detail view shares the same card shell, row spacing,
  value containers, and empty-value formatting.
  """

  use Phoenix.Component

  @doc """
  Renders the outer details card for an admin show page.

  Wraps the supplied rows in the shared `<dl>` shell so that all admin
  detail views share the same card chrome and grid alignment.
  """
  slot :inner_block, required: true

  def detail_card(assigns) do
    ~H"""
    <dl class="card card-body bg-base-100 shadow-md grid grid-cols-1 sm:grid-cols-[auto_1fr] gap-5">
      {render_slot(@inner_block)}
    </dl>
    """
  end

  @doc """
  Renders a single labeled row inside a `detail_card/1`.

  Pass `:show` as `false` to omit the row entirely (for example when the
  underlying value is `nil`). Inner content is rendered inside the value
  container so callers can freely embed badges, links, or fallback text.
  """
  attr :label, :string, required: true
  attr :show, :boolean, default: true
  slot :inner_block, required: true

  def detail_row(assigns) do
    ~H"""
    <div :if={@show} class="col-span-full grid grid-cols-subgrid gap-y-1 items-baseline">
      <dt class="font-medium sm:text-right">{@label}</dt>
      <dd class="bg-base-200 p-3 rounded-lg inset-shadow-sm overflow-x-auto">
        {render_slot(@inner_block)}
      </dd>
    </div>
    """
  end

  @doc """
  Formats a timestamp consistently across all admin detail views.

  Returns the shared placeholder for missing values so empty rows render
  the same way regardless of the source field.
  """
  def format_admin_timestamp(nil), do: empty_value()

  def format_admin_timestamp(%NaiveDateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S\u00A0UTC")
  end

  def format_admin_timestamp(%DateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S\u00A0UTC")
  end

  def format_admin_timestamp(other), do: inspect(other)

  @doc """
  The placeholder string used by admin detail views for empty/missing values.
  """
  def empty_value, do: "—"
end
