defmodule Apex.Discovery.Search.Ranker do
  @moduledoc """
  Pure ranking. Turns matched documents into ordered `Result`s.

  Ordering is defined by a layered key, most significant first (spec FR-007/FR-008):

    1. **Exact-identifier band** — the query exactly equals a searchable field
       (e.g. an invoice number). Guarantees `INV-123` outranks loose name matches
       *structurally*, not by weight tuning.
    2. **Text relevance** — best per-field match strength: exact `1.0` > prefix
       `0.7` > substring `0.4`.
    3. **Source/type weight** — the source's fixed `type_weight`.
    4. **Recency** — newer `updated_at` breaks remaining ties.

  Being a pure function of `(documents, normalized_query)` makes it trivially
  testable.
  """

  alias Apex.Discovery.Search.{Document, Registry, Result, Normalizer}

  @exact 1.0
  @prefix 0.7
  @substring 0.4

  @doc "Score, filter to actual matches, and order documents into results (best first)."
  @spec rank([Document.t()], String.t()) :: [Result.t()]
  def rank(documents, normalized_query) do
    documents
    |> Enum.map(&score(&1, normalized_query))
    |> Enum.reject(&(&1.relevance == 0.0))
    |> Enum.sort_by(&sort_key/1, :desc)
    |> Enum.map(&to_result/1)
  end

  # --- Scoring ---------------------------------------------------------------

  defp score(%Document{} = doc, nq) do
    field_strengths =
      for {field, value} <- doc.search_terms, into: %{} do
        {field, strength(Normalizer.normalize(value), nq)}
      end

    # Title/subtitle contribute to relevance/exactness but not to matched_fields.
    extra = [
      strength(Normalizer.normalize(doc.title), nq),
      strength(Normalizer.normalize(doc.subtitle), nq)
    ]

    strengths = Map.values(field_strengths) ++ extra
    relevance = Enum.max([0.0 | strengths])
    matched_fields = for {field, s} <- field_strengths, s > 0.0, do: field

    %{
      doc: doc,
      relevance: relevance,
      exact?: relevance == @exact,
      matched_fields: Enum.sort(matched_fields)
    }
  end

  defp strength("", _nq), do: 0.0
  defp strength(_value, ""), do: 0.0

  defp strength(value, nq) do
    cond do
      value == nq -> @exact
      String.starts_with?(value, nq) -> @prefix
      String.contains?(value, nq) -> @substring
      true -> 0.0
    end
  end

  # --- Ordering --------------------------------------------------------------

  # Higher tuple sorts first (:desc). Booleans order false < true, so exact? wins.
  defp sort_key(%{doc: doc, relevance: relevance, exact?: exact?}) do
    {exact?, relevance, type_weight(doc.source), recency(doc.updated_at)}
  end

  defp type_weight(source) do
    case Registry.module(source) do
      nil -> 0.0
      mod -> mod.type_weight()
    end
  end

  defp recency(nil), do: 0
  defp recency(%DateTime{} = dt), do: DateTime.to_unix(dt)

  # --- Projection ------------------------------------------------------------

  defp to_result(%{doc: doc, relevance: relevance, matched_fields: matched_fields}) do
    %Result{
      source: doc.source,
      id: doc.id,
      title: doc.title,
      subtitle: doc.subtitle,
      url: doc.url,
      score: Float.round(relevance, 2),
      matched_fields: matched_fields,
      metadata: doc.metadata
    }
  end
end
