defmodule Claper.Transcriptions.MistralRealtimeClient do
  @moduledoc """
  WebSocket client for Mistral's realtime transcription API.
  Connects to wss://api.mistral.ai/v1/audio/transcriptions/realtime
  and streams PCM audio for real-time transcription.
  Auto-reconnects when the server closes the connection after a segment.
  """

  use WebSockex

  require Logger

  @base_url "wss://api.mistral.ai/v1/audio/transcriptions/realtime"
  @model "voxtral-mini-transcribe-realtime-2602"

  defstruct [:callback_pid, :language, session_ready: false]

  def start_link(opts) do
    callback_pid = Keyword.fetch!(opts, :callback_pid)
    language = Keyword.get(opts, :language)
    api_key = get_api_key()

    url = "#{@base_url}?model=#{@model}"

    headers = [
      {"Authorization", "Bearer #{api_key}"}
    ]

    state = %__MODULE__{
      callback_pid: callback_pid,
      language: language
    }

    WebSockex.start_link(url, __MODULE__, state, extra_headers: headers)
  end

  def send_audio(pid, pcm_data) when is_binary(pcm_data) do
    message =
      Jason.encode!(%{
        "type" => "input_audio.append",
        "audio" => Base.encode64(pcm_data)
      })

    WebSockex.send_frame(pid, {:text, message})
  end

  def end_audio(pid) do
    message = Jason.encode!(%{"type" => "input_audio.end"})
    WebSockex.send_frame(pid, {:text, message})
  end

  # WebSockex callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("MistralRealtimeClient: connected, sending session config")
    send(self(), :send_session_update)
    {:ok, %{state | session_ready: false}}
  end

  @impl true
  def handle_info(:send_session_update, state) do
    session_config = %{
      "audio_format" => %{"encoding" => "pcm_s16le", "sample_rate" => 16_000}
    }

    message = Jason.encode!(%{"type" => "session.update", "session" => session_config})
    {:reply, {:text, message}, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, event} ->
        handle_event(event, state)

      {:error, reason} ->
        Logger.error("MistralRealtimeClient: failed to parse: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl true
  def handle_frame({:binary, _data}, state) do
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.info("MistralRealtimeClient: disconnected (#{inspect(reason)}), reconnecting...")
    send(state.callback_pid, {:mistral_event, :disconnected, reason})
    {:reconnect, state}
  end

  defp handle_event(%{"type" => "session.created"} = event, state) do
    Logger.info("MistralRealtimeClient: session created")
    send(state.callback_pid, {:mistral_event, :session_created, event})
    {:ok, %{state | session_ready: true}}
  end

  defp handle_event(%{"type" => "session.updated"}, state) do
    Logger.info("MistralRealtimeClient: session updated, ready for audio")
    {:ok, state}
  end

  defp handle_event(%{"type" => "transcription.text.delta", "text" => text}, state) do
    send(state.callback_pid, {:mistral_event, :text_delta, text})
    {:ok, state}
  end

  defp handle_event(%{"type" => "transcription.segment", "text" => text}, state) do
    send(state.callback_pid, {:mistral_event, :segment, text})
    {:ok, state}
  end

  defp handle_event(%{"type" => "transcription.done"} = event, state) do
    text = Map.get(event, "text", "")
    send(state.callback_pid, {:mistral_event, :done, text})
    {:ok, state}
  end

  defp handle_event(%{"type" => "transcription.language"} = event, state) do
    lang = Map.get(event, "audioLanguage") || Map.get(event, "language")

    Logger.info("MistralRealtimeClient: detected language #{lang}")
    send(state.callback_pid, {:mistral_event, :language, lang})
    {:ok, state}
  end

  defp handle_event(%{"type" => "error"} = event, state) do
    error_msg = get_in(event, ["error", "message"]) || "unknown error"
    Logger.error("MistralRealtimeClient: error - #{error_msg}")
    send(state.callback_pid, {:mistral_event, :error, error_msg})
    {:ok, state}
  end

  defp handle_event(event, state) do
    Logger.info(
      "MistralRealtimeClient: unhandled event type #{inspect(event["type"])} payload=#{inspect(event)}"
    )

    {:ok, state}
  end

  defp get_api_key do
    Claper.Settings.get_transcription_api_key()
  end
end
