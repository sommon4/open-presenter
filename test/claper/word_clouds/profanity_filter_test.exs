defmodule Claper.WordClouds.ProfanityFilterTest do
  use ExUnit.Case, async: true

  alias Claper.WordClouds.ProfanityFilter

  test "matches block-listed words exactly, in any case and with leetspeak" do
    assert ProfanityFilter.profane?("shit")
    assert ProfanityFilter.profane?("SHIT")
    assert ProfanityFilter.profane?("$h1t")
    assert ProfanityFilter.profane?("f.u.c.k")
    assert ProfanityFilter.profane?("this is shit")
  end

  test "does not match substrings (Scunthorpe problem)" do
    refute ProfanityFilter.profane?("class")
    refute ProfanityFilter.profane?("assume")
    refute ProfanityFilter.profane?("analysis")
    refute ProfanityFilter.profane?("Scunthorpe")
    refute ProfanityFilter.profane?("hello")
    refute ProfanityFilter.profane?("")
    refute ProfanityFilter.profane?(nil)
  end

  test "extra words from the application config are included" do
    Application.put_env(:claper, :word_cloud_profanity_words, ["blorp"])
    on_exit(fn -> Application.delete_env(:claper, :word_cloud_profanity_words) end)

    assert ProfanityFilter.profane?("Blorp")
    refute ProfanityFilter.profane?("blorps")
  end
end
