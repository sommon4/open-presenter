defmodule Claper.WordClouds.NormalizerTest do
  use ExUnit.Case, async: true

  alias Claper.WordClouds.Normalizer

  describe "normalize/2" do
    test "trims and case folds" do
      assert {:ok, %{display: "Genetics", normalized: "genetics"}} =
               Normalizer.normalize(" Genetics ")

      assert {:ok, %{normalized: "genetics"}} = Normalizer.normalize("GENETICS")
      assert {:ok, %{normalized: "genetics"}} = Normalizer.normalize("genetics")
    end

    test "keeps case when merge_case is false" do
      assert {:ok, %{display: "AI", normalized: "AI"}} =
               Normalizer.normalize("AI", merge_case: false)
    end

    test "collapses repeated whitespace and keeps multi-word phrases" do
      assert {:ok, %{display: "rare disease", normalized: "rare disease"}} =
               Normalizer.normalize("rare    disease")

      assert {:ok, %{display: "rare disease"}} = Normalizer.normalize("rare\tdisease\n")
    end

    test "rejects empty and whitespace-only input" do
      assert {:error, :empty} = Normalizer.normalize("")
      assert {:error, :empty} = Normalizer.normalize("   ")
      assert {:error, :empty} = Normalizer.normalize(nil)
      assert {:error, :empty} = Normalizer.normalize("<b></b>")
    end

    test "rejects answers over max_characters (in graphemes, not bytes)" do
      assert {:error, :too_long} = Normalizer.normalize(String.duplicate("a", 41))
      assert {:ok, _} = Normalizer.normalize(String.duplicate("a", 40))
      # 10 Thai characters, many bytes
      assert {:ok, _} = Normalizer.normalize("พันธุกรรมศาสตร์", max_characters: 15)
      assert {:error, :too_long} = Normalizer.normalize("พันธุกรรมศาสตร์", max_characters: 5)
    end

    test "handles Unicode input and NFC normalization" do
      # "é" as e + combining acute equals precomposed "é"
      decomposed = "génétique"
      precomposed = "génétique"

      assert {:ok, %{normalized: a}} = Normalizer.normalize(decomposed)
      assert {:ok, %{normalized: b}} = Normalizer.normalize(precomposed)
      assert a == b

      assert {:ok, %{display: "遺伝学", normalized: "遺伝学"}} = Normalizer.normalize("遺伝学")
      assert {:ok, %{display: "พันธุกรรม"}} = Normalizer.normalize(" พันธุกรรม ")
    end

    test "strips HTML tags and script input" do
      assert {:ok, %{display: "alert(1)"}} =
               Normalizer.normalize("<script>alert(1)</script>")

      assert {:ok, %{display: "bold"}} = Normalizer.normalize("<b>bold</b>")
      assert {:ok, %{display: "a b"}} = Normalizer.normalize("a <img src=x onerror=alert(1)> b")
    end

    test "strips control and zero-width characters" do
      assert {:ok, %{display: "genetics"}} = Normalizer.normalize("gen​etics\u0000")
    end

    test "drops invalid UTF-8 bytes" do
      assert {:ok, %{display: "ab"}} = Normalizer.normalize(<<"a", 0xFF, "b">>)
    end
  end
end
