defmodule Apex.Discovery.Search.Normalizer do
  @moduledoc """
  Text normalisation for matching, applied identically to indexed terms and to the
  query so matching is symmetric (spec FR-015).

  Version one folds the high-value, low-cost differences:

    * case (`String.downcase/1`),
    * Unicode compatibility decomposition (NFKD), then
    * removal of combining marks — which strips both Latin accents (e.g. `é → e`)
      and Arabic diacritics / tashkīl (e.g. `مُحَمَّد → محمد`).

  Deferred (documented non-goals): stemming, synonym expansion, Arabic
  alef/hamza normalisation and transliteration.
  """

  @combining_marks ~r/\p{Mn}/u
  @whitespace ~r/\s+/u

  @doc """
  Normalises text for matching. `nil` normalises to an empty string.

      iex> Apex.Discovery.Search.Normalizer.normalize("INV-123")
      "inv-123"

      iex> Apex.Discovery.Search.Normalizer.normalize("  Gulf   Trading ")
      "gulf trading"
  """
  @spec normalize(String.t() | nil) :: String.t()
  def normalize(nil), do: ""

  def normalize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfkd)
    |> String.replace(@combining_marks, "")
    |> String.replace(@whitespace, " ")
    |> String.trim()
  end
end
