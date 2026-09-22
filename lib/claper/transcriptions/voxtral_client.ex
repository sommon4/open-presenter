defmodule Claper.Transcriptions.VoxtralClient do
  @moduledoc """
  Client for the Mistral Voxtral Mini transcription API.
  """

  require Logger

  @api_url "https://api.mistral.ai/v1/audio/transcriptions"

  def transcribe(audio_data, opts \\ []) do
    api_key = get_api_key()

    if is_nil(api_key) do
      {:error, :missing_api_key}
    else
      language = Keyword.get(opts, :language)

      multipart =
        [
          {"file", {audio_data, filename: "audio.webm", content_type: "audio/webm"}},
          {"model", "voxtral-mini-latest"}
        ]
        |> maybe_add_language(language)

      case Req.post(@api_url,
             headers: [{"authorization", "Bearer #{api_key}"}],
             form_multipart: multipart,
             receive_timeout: 30_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok,
           %{
             text: body["text"] || "",
             language: body["language"],
             segments: body["segments"] || []
           }}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Voxtral API error: status=#{status} body=#{inspect(body)}")
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          Logger.error("Voxtral API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp maybe_add_language(multipart, nil), do: multipart
  defp maybe_add_language(multipart, lang), do: multipart ++ [{"language", lang}]

  defp get_api_key do
    Claper.Settings.get_transcription_api_key()
  end
end
