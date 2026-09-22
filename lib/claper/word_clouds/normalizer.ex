defmodule Claper.WordClouds.Normalizer do
  @moduledoc """
  Turns a raw attendee answer into a display form and an aggregation key.

  Pipeline:

      input
       ↓ strip HTML tags, control and zero-width characters
       ↓ trim leading/trailing whitespace
       ↓ collapse repeated whitespace
       ↓ Unicode NFC normalization              → display form
       ↓ case fold (optional)                   → normalized key
       ↓ length validation

  An answer is a *text response*: it can be a multi-word phrase and it can be
  Thai, Chinese or Japanese, so the pipeline never splits on whitespace.
  """

  @type result ::
          {:ok, %{display: String.t(), normalized: String.t()}}
          | {:error, :empty | :too_long}

  @doc """
  Normalizes `input`.

  ## Options

    * `:max_characters` — maximum length of the display form (default 40)
    * `:merge_case` — when `true` (default) the key is case folded, so
      "Genetics", "GENETICS" and " genetics " all count as `genetics`.

  ## Examples

      iex> Claper.WordClouds.Normalizer.normalize(" Genetics ")
      {:ok, %{display: "Genetics", normalized: "genetics"}}

      iex> Claper.WordClouds.Normalizer.normalize("   ")
      {:error, :empty}
  """
  @spec normalize(String.t() | nil, keyword()) :: result()
  def normalize(input, opts \\ [])

  def normalize(nil, _opts), do: {:error, :empty}

  def normalize(input, opts) when is_binary(input) do
    max_characters = Keyword.get(opts, :max_characters, 40)
    merge_case = Keyword.get(opts, :merge_case, true)

    display =
      input
      |> strip_invalid_utf8()
      |> strip_tags()
      |> strip_control_characters()
      |> String.trim()
      |> collapse_whitespace()
      |> unicode_normalize()

    cond do
      display == "" ->
        {:error, :empty}

      String.length(display) > max_characters ->
        {:error, :too_long}

      true ->
        {:ok, %{display: display, normalized: key(display, merge_case)}}
    end
  end

  @doc """
  Computes the aggregation key of an already cleaned display form.
  """
  @spec key(String.t(), boolean()) :: String.t()
  def key(display, true), do: String.downcase(display)
  def key(display, false), do: display

  defp strip_invalid_utf8(input) do
    if String.valid?(input) do
      input
    else
      input
      |> String.chunk(:valid)
      |> Enum.filter(&String.valid?/1)
      |> Enum.join()
    end
  end

  # Anything shaped like a tag is removed. Output is always HTML-escaped by the
  # templates anyway; this only keeps markup out of the stored data.
  defp strip_tags(input), do: Regex.replace(~r/<[^>]*>/u, input, "")

  # Cc = control characters, Cf = format characters (zero-width joiners,
  # direction marks, ...). A plain tab or newline is a separator, so it is
  # replaced by a space before it is dropped.
  defp strip_control_characters(input) do
    input
    |> String.replace(~r/[\t\r\n]/u, " ")
    |> String.replace(~r/[\p{Cc}\p{Cf}]/u, "")
  end

  defp collapse_whitespace(input), do: Regex.replace(~r/\s+/u, input, " ")

  defp unicode_normalize(input), do: String.normalize(input, :nfc)
end
