defmodule Claper.OpenEndedFixtures do
  @moduledoc """
  Test helpers for the `Claper.OpenEnded` context.
  """

  import Claper.PresentationsFixtures

  def open_ended_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    presentation_file_id = attrs[:presentation_file_id] || presentation_file_fixture().id

    {:ok, open_ended} =
      attrs
      |> Enum.into(%{
        title: "What is the best advice you have ever been given?",
        position: 0,
        enabled: true,
        max_characters: 200,
        presentation_file_id: presentation_file_id
      })
      |> Claper.OpenEnded.create_open_ended()

    open_ended
  end
end
