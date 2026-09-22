defmodule Claper.WordCloudsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.WordClouds` context.
  """

  import Claper.PresentationsFixtures

  @doc """
  Generate a word cloud. Pass `:presentation_file_id` to attach it to an
  existing presentation, otherwise a presentation file is created.
  """
  def word_cloud_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    presentation_file_id =
      attrs[:presentation_file_id] || presentation_file_fixture().id

    {:ok, word_cloud} =
      attrs
      |> Enum.into(%{
        title: "What comes to mind when you hear genetic testing?",
        position: 0,
        enabled: true,
        max_answers: 3,
        max_characters: 40,
        presentation_file_id: presentation_file_id
      })
      |> Claper.WordClouds.create_word_cloud()

    word_cloud
  end
end
