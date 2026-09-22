defmodule Claper.Transcriptions.TranscriptionWorkerTest do
  use Claper.DataCase

  import Claper.PresentationsFixtures

  alias Claper.Transcriptions
  alias Claper.Transcriptions.TranscriptionWorker

  test "persists detected language on saved transcriptions" do
    presentation_file = presentation_file_fixture()

    state = %{
      event_uuid: Ecto.UUID.generate(),
      presentation_file_id: presentation_file.id,
      language: nil,
      current_text: "",
      clear_timer: nil
    }

    {:noreply, state} =
      TranscriptionWorker.handle_info({:mistral_event, :language, "fr"}, state)

    {:noreply, _state} =
      TranscriptionWorker.handle_info({:mistral_event, :segment, "Bonjour tout le monde"}, state)

    assert [%{language: "fr", text: "Bonjour tout le monde"}] =
             Transcriptions.list_transcriptions(presentation_file.id)
  end
end
