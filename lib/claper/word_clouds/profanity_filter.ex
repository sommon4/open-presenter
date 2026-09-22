defmodule Claper.WordClouds.ProfanityFilter do
  @moduledoc """
  Optional profanity check for Word Cloud answers.

  The check is an *exact match* of each word of the answer against a block
  list, after a light normalization (lower case, common leetspeak
  substitutions, non-letters removed). It is never a substring match, so
  "class", "assume" or "Scunthorpe" pass.

  The block list is the built-in list plus the words given in the
  `:word_cloud_profanity_words` application setting (see `config/runtime.exs`,
  environment variable `WORD_CLOUD_PROFANITY_WORDS`, comma separated).
  """

  @builtin ~w(
    fuck fucker fucking motherfucker shit bullshit shite asshole arsehole
    bitch bastard cunt dick dickhead cock pussy twat wanker prick slut whore
    nigger nigga faggot fag retard
  )

  @leet %{
    "0" => "o",
    "1" => "i",
    "!" => "i",
    "|" => "i",
    "3" => "e",
    "4" => "a",
    "@" => "a",
    "5" => "s",
    "$" => "s",
    "7" => "t",
    "8" => "b"
  }

  @doc """
  Returns `true` when any word of `text` is on the block list.
  """
  @spec profane?(String.t() | nil) :: boolean()
  def profane?(nil), do: false
  def profane?(""), do: false

  def profane?(text) when is_binary(text) do
    list = block_list()

    text
    |> String.split(~r/\s+/u, trim: true)
    |> Enum.any?(fn word -> MapSet.member?(list, normalize_word(word)) end)
  end

  @doc """
  The active block list as a `MapSet` of normalized words.
  """
  @spec block_list() :: MapSet.t()
  def block_list do
    extra =
      Application.get_env(:claper, :word_cloud_profanity_words, [])
      |> List.wrap()

    (@builtin ++ extra)
    |> Enum.map(&normalize_word/1)
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new()
  end

  @doc false
  def normalize_word(word) do
    word
    |> String.downcase()
    |> String.graphemes()
    |> Enum.map(fn g -> Map.get(@leet, g, g) end)
    |> Enum.filter(&String.match?(&1, ~r/^\p{L}$/u))
    |> Enum.join()
  end
end
