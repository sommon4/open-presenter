defmodule ClaperWeb.ModalComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="modal"
      class="modal modal-open"
      role="dialog"
      aria-labelledby="modal-title"
      aria-modal="true"
      phx-remove={hide_modal()}
      phx-window-keydown={hide_modal()}
      phx-key="escape"
      phx-target={@myself}
    >
      <div class="modal-box">
        <button
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click={hide_modal()}
          phx-target={@myself}
        >
          &times;
        </button>

        <h3 class="text-lg font-bold" id="modal-title">
          {@title}
        </h3>
        <p class="py-2 text-sm text-gray-500">
          {@description}
        </p>
        <div class="mt-2">
          {render_slot(@inner_block)}
        </div>
      </div>
      <div class="modal-backdrop" phx-click={hide_modal()} phx-target={@myself}>
        <button>close</button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("hide", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: socket.assigns.return_to)}
  end

  def hide_modal(js \\ %JS{}) do
    js
    |> JS.push("hide", target: "#modal", page_loading: true)
  end
end
