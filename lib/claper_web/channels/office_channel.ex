defmodule ClaperWeb.OfficeChannel do
  @moduledoc """
  Pushes live results to the PowerPoint add-in.

  Topics:

    * `interaction:<public id>` (for example `interaction:word_cloud_12`):
      pushes `interaction_updated`, `interaction_started`,
      `interaction_stopped` and `interaction_deleted` for that interaction.
    * `event:<uuid>`: pushes `state_updated`, `current_interaction`
      (payload may be `null`), `post_created`, `post_updated`,
      `post_deleted` and `interaction_updated` for every interaction of the
      event.

  Both topics reuse the application's PubSub, so the add-in sees exactly what
  the browser presenter sees.
  """
  use Phoenix.Channel, log_handle_in: false

  alias Claper.Office
  alias Claper.Office.Serializer

  @interaction_events ~w(poll_updated poll_deleted form_updated form_deleted embed_updated
    embed_deleted quiz_updated quiz_deleted word_cloud_updated word_cloud_deleted
    open_ended_updated open_ended_deleted)a

  @impl true
  def join("interaction:" <> id, _params, socket) do
    with true <- Office.has_scope?(socket.assigns.office_token, "office:interactions:read"),
         {:ok, interaction, event} <- Office.get_interaction(socket.assigns.user, id) do
      subscribe(event)

      socket =
        socket
        |> assign(:mode, :interaction)
        |> assign(:event, event)
        |> assign(:interaction_id, id)

      {:ok, %{interaction: Serializer.interaction(interaction, event)}, socket}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  def join("event:" <> uuid, _params, socket) do
    with true <- Office.has_scope?(socket.assigns.office_token, "office:events:read"),
         {:ok, event} <- Office.get_event(socket.assigns.user, uuid) do
      subscribe(event)
      {:ok, %{event: Serializer.event(event)}, assign(socket, mode: :event, event: event)}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  defp subscribe(event) do
    Claper.Events.Event.subscribe(event.uuid)
    Claper.Presentations.subscribe(event.presentation_file.id)
  end

  @impl true
  def handle_in("refresh", _params, %{assigns: %{mode: :interaction}} = socket) do
    case Office.get_interaction(socket.assigns.user, socket.assigns.interaction_id) do
      {:ok, interaction, event} ->
        {:reply, {:ok, %{interaction: Serializer.interaction(interaction, event)}}, socket}

      _ ->
        {:reply, {:error, %{reason: "not_found"}}, socket}
    end
  end

  def handle_in("refresh", _params, socket) do
    {:reply, {:ok, %{event: Serializer.event(socket.assigns.event)}}, socket}
  end

  ## PubSub → channel

  @impl true
  def handle_info({event_name, struct}, socket) when event_name in @interaction_events do
    if relevant?(socket, struct) do
      cond do
        String.ends_with?(Atom.to_string(event_name), "_deleted") ->
          push(socket, "interaction_deleted", %{id: Office.public_id(struct)})

        true ->
          fresh = Office.reload(struct, socket.assigns.event) || struct

          push(socket, "interaction_updated", %{
            interaction: Serializer.interaction(fresh, socket.assigns.event)
          })
      end
    end

    {:noreply, socket}
  end

  def handle_info({:current_interaction, nil}, socket) do
    case socket.assigns.mode do
      :interaction -> push(socket, "interaction_stopped", %{id: socket.assigns.interaction_id})
      :event -> push(socket, "current_interaction", %{interaction: nil})
    end

    {:noreply, socket}
  end

  def handle_info({:current_interaction, interaction}, socket) do
    fresh = Office.reload(interaction, socket.assigns.event) || interaction
    payload = %{interaction: Serializer.interaction(fresh, socket.assigns.event)}

    case socket.assigns.mode do
      :interaction ->
        if Office.public_id(interaction) == socket.assigns.interaction_id do
          push(socket, "interaction_started", payload)
        else
          push(socket, "interaction_stopped", %{id: socket.assigns.interaction_id})
        end

      :event ->
        push(socket, "current_interaction", payload)
    end

    {:noreply, socket}
  end

  def handle_info({:state_updated, state}, socket) do
    push(socket, "state_updated", Serializer.state(state))
    {:noreply, socket}
  end

  def handle_info({post_event, %Claper.Posts.Post{} = post}, %{assigns: %{mode: :event}} = socket)
      when post_event in [
             :post_created,
             :post_updated,
             :post_deleted,
             :post_pinned,
             :post_unpinned,
             :reaction_added,
             :reaction_removed
           ] do
    push(socket, Atom.to_string(post_event), %{post: Serializer.post(post)})
    {:noreply, socket}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp relevant?(%{assigns: %{mode: :event}}, _struct), do: true

  defp relevant?(%{assigns: %{mode: :interaction, interaction_id: id}}, struct),
    do: Office.public_id(struct) == id
end
