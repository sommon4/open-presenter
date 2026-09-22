defmodule ClaperWeb.AudioChannel do
  use Phoenix.Channel, log_handle_in: false

  require Logger

  alias Claper.Transcriptions.TranscriptionWorker

  @impl true
  def join("audio:" <> event_uuid, _params, socket) do
    if socket.assigns[:authorized_event_uuid] == event_uuid do
      {:ok, assign(socket, :event_uuid, event_uuid)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("audio_chunk", %{"data" => base64_audio}, socket) do
    case Base.decode64(base64_audio) do
      {:ok, audio_data} ->
        try do
          TranscriptionWorker.push_audio(socket.assigns.event_uuid, audio_data)
        catch
          kind, reason ->
            Logger.warning("Failed to push audio: #{inspect(kind)} #{inspect(reason)}")
        end

        {:noreply, socket}

      :error ->
        Logger.warning("Received invalid base64 audio data")
        {:noreply, socket}
    end
  end
end
