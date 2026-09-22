defmodule Claper.Transcriptions.MistralRealtimeClientTest do
  use ExUnit.Case, async: true

  alias Claper.Transcriptions.MistralRealtimeClient

  test "does not send language in realtime session update" do
    state = %MistralRealtimeClient{callback_pid: self(), language: "fr"}

    assert {:reply, {:text, message}, ^state} =
             MistralRealtimeClient.handle_info(:send_session_update, state)

    assert %{
             "type" => "session.update",
             "session" => %{
               "audio_format" => %{"encoding" => "pcm_s16le", "sample_rate" => 16_000}
             }
           } = Jason.decode!(message)

    refute Map.has_key?(Jason.decode!(message)["session"], "language")
  end

  test "emits language event from audioLanguage payload" do
    state = %MistralRealtimeClient{callback_pid: self()}
    message = Jason.encode!(%{"type" => "transcription.language", "audioLanguage" => "fr"})

    assert {:ok, ^state} = MistralRealtimeClient.handle_frame({:text, message}, state)
    assert_receive {:mistral_event, :language, "fr"}
  end

  test "emits language event from language payload" do
    state = %MistralRealtimeClient{callback_pid: self()}
    message = Jason.encode!(%{"type" => "transcription.language", "language" => "de"})

    assert {:ok, ^state} = MistralRealtimeClient.handle_frame({:text, message}, state)
    assert_receive {:mistral_event, :language, "de"}
  end
end
