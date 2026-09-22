defmodule Claper.Workers.PresentationThumbnails do
  use Oban.Worker, queue: :default

  alias Claper.{Events, Presentations}
  alias Claper.Tasks.Converter

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"presentation_file_id" => presentation_file_id, "user_id" => user_id}
      }) do
    presentation_file = Presentations.get_presentation_file!(presentation_file_id)

    case Converter.regenerate_thumbnails(presentation_file) do
      :ok ->
        Events.broadcast_user_events(
          user_id,
          {:presentation_file_thumbnails_regenerated, presentation_file_id}
        )

        :ok

      {:error, _reason} = error ->
        Events.broadcast_user_events(
          user_id,
          {:presentation_file_thumbnail_regeneration_failed, presentation_file_id}
        )

        error
    end
  end

  def create(presentation_file_id, user_id) do
    new(%{
      "presentation_file_id" => presentation_file_id,
      "user_id" => user_id
    })
  end
end
