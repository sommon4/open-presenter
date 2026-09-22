defmodule Claper.Transcriptions.TranscriptionWorker do
  @moduledoc """
  GenServer that manages transcription for an active event.
  Maintains a persistent WebSocket connection to Mistral's realtime API
  and streams PCM audio for real-time transcription.
  """

  use GenServer

  require Logger

  alias Claper.Transcriptions
  alias Claper.Transcriptions.MistralRealtimeClient

  # Client API

  def start_link({event_uuid, presentation_file_id}) do
    GenServer.start_link(__MODULE__, {event_uuid, presentation_file_id}, name: via(event_uuid))
  end

  def push_audio(event_uuid, audio_chunk) do
    case Registry.lookup(Claper.TranscriptionRegistry, event_uuid) do
      [{pid, _}] -> GenServer.cast(pid, {:audio_chunk, audio_chunk})
      [] -> {:error, :worker_not_running}
    end
  end

  def stop(event_uuid) do
    case Registry.lookup(Claper.TranscriptionRegistry, event_uuid) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
  end

  def running?(event_uuid) do
    Registry.lookup(Claper.TranscriptionRegistry, event_uuid) != []
  end

  # Server callbacks

  @impl true
  def init({event_uuid, presentation_file_id}) do
    if Claper.Settings.transcription_globally_enabled?() do
      Logger.info("TranscriptionWorker started for event #{event_uuid}")

      config_language =
        case Transcriptions.get_transcription_config(presentation_file_id) do
          %{language: lang} when is_binary(lang) and lang != "" -> lang
          _ -> Claper.Settings.get("transcription_default_language")
        end

      # Connect to Mistral realtime API
      opts = [callback_pid: self()]
      opts = if config_language, do: Keyword.put(opts, :language, config_language), else: opts

      case MistralRealtimeClient.start_link(opts) do
        {:ok, ws_pid} ->
          {:ok,
           %{
             event_uuid: event_uuid,
             presentation_file_id: presentation_file_id,
             language: config_language,
             ws_pid: ws_pid,
             current_text: "",
             clear_timer: nil
           }}

        {:error, reason} ->
          Logger.error("Failed to connect to Mistral realtime API: #{inspect(reason)}")
          {:stop, reason}
      end
    else
      Logger.info("TranscriptionWorker: transcription globally disabled, not starting")
      {:stop, :transcription_disabled}
    end
  end

  @impl true
  def handle_cast({:audio_chunk, audio_data}, state) do
    if state.ws_pid && Process.alive?(state.ws_pid) do
      try do
        MistralRealtimeClient.send_audio(state.ws_pid, audio_data)
      catch
        :exit, _ -> :ok
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:mistral_event, :text_delta, text}, state) do
    new_text = state.current_text <> text
    cancel_clear_timer(state)
    Transcriptions.broadcast_transcription_delta(state.event_uuid, last_sentences(new_text, 2))
    timer = Process.send_after(self(), :clear_subtitle, 2_000)
    {:noreply, %{state | current_text: new_text, clear_timer: timer}}
  end

  @impl true
  def handle_info({:mistral_event, :segment, text}, state) do
    cancel_clear_timer(state)
    save_and_broadcast(text, state)
    Transcriptions.broadcast_transcription_delta(state.event_uuid, last_sentences(text, 2))
    timer = Process.send_after(self(), :clear_subtitle, 2_000)
    {:noreply, %{state | current_text: "", clear_timer: timer}}
  end

  @impl true
  def handle_info({:mistral_event, :done, text}, state) do
    cancel_clear_timer(state)

    # Save accumulated delta text, or fall back to the done event text
    text_to_save = if state.current_text != "", do: state.current_text, else: text
    save_and_broadcast(text_to_save, state)

    timer = Process.send_after(self(), :clear_subtitle, 3_000)
    {:noreply, %{state | current_text: "", clear_timer: timer}}
  end

  @impl true
  def handle_info(:clear_subtitle, state) do
    if state.current_text != "" do
      save_and_broadcast(state.current_text, state)
    end

    Transcriptions.broadcast_transcription_delta(state.event_uuid, "")
    {:noreply, %{state | current_text: "", clear_timer: nil}}
  end

  @impl true
  def handle_info({:mistral_event, :session_created, _event}, state) do
    Logger.info("TranscriptionWorker: Mistral session ready for event #{state.event_uuid}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:mistral_event, :language, lang}, state) do
    Logger.info("TranscriptionWorker: detected language #{lang} for event #{state.event_uuid}")
    {:noreply, %{state | language: lang}}
  end

  @impl true
  def handle_info({:mistral_event, :error, error_msg}, state) do
    Logger.error("TranscriptionWorker: Mistral error for event #{state.event_uuid}: #{error_msg}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:mistral_event, :disconnected, _reason}, state) do
    Logger.warning("TranscriptionWorker: Mistral disconnected for event #{state.event_uuid}")

    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "TranscriptionWorker stopping for event #{state.event_uuid}, reason: #{inspect(reason)}"
    )

    if state[:ws_pid] && Process.alive?(state.ws_pid) do
      MistralRealtimeClient.end_audio(state.ws_pid)
    end

    :ok
  end

  defp cancel_clear_timer(%{clear_timer: ref}) when is_reference(ref) do
    Process.cancel_timer(ref)
  end

  defp cancel_clear_timer(_), do: :ok

  defp last_sentences(text, n) when is_binary(text) do
    sentences = Regex.split(~r/(?<=[.!?])\s+/, String.trim(text))

    sentences
    |> Enum.slice(-n, n)
    |> Enum.join(" ")
  end

  defp save_and_broadcast(text, state) when is_binary(text) and text != "" do
    case Transcriptions.create_transcription(%{
           text: text,
           language: state.language,
           presentation_file_id: state.presentation_file_id
         }) do
      {:ok, transcription} ->
        Transcriptions.broadcast_transcription(state.event_uuid, transcription)

      {:error, reason} ->
        Logger.error("Failed to save transcription: #{inspect(reason)}")
    end
  end

  defp save_and_broadcast(_, _), do: :ok

  defp via(event_uuid) do
    {:via, Registry, {Claper.TranscriptionRegistry, event_uuid}}
  end
end
