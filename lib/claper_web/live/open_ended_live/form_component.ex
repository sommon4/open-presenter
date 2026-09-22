defmodule ClaperWeb.OpenEndedLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.OpenEnded

  @impl true
  def update(%{open_ended: open_ended} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, OpenEnded.change_open_ended(open_ended))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case OpenEnded.get_open_ended_for_event(id, socket.assigns.presentation_file.event_id) do
      nil ->
        {:noreply, socket}

      open_ended ->
        {:ok, _} = OpenEnded.delete_open_ended(socket.assigns.event_uuid, open_ended)
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  @impl true
  def handle_event("validate", %{"open_ended" => params}, socket) do
    changeset =
      socket.assigns.open_ended
      |> OpenEnded.change_open_ended(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"open_ended" => params}, socket) do
    save(socket, socket.assigns.live_action, params)
  end

  defp save(socket, :edit, params) do
    params = Map.drop(params, ["position", "enabled", "presentation_file_id"])

    case OpenEnded.update_open_ended(socket.assigns.event_uuid, socket.assigns.open_ended, params) do
      {:ok, _} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save(socket, :new, params) do
    case OpenEnded.create_open_ended(
           params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, _} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
