defmodule Apex.Discovery.Search.Index do
  @moduledoc """
  The swappable storage/retrieval contract for the search projection.

  The in-memory adapter (`Apex.Discovery.Search.Index.InMemory`) implements this for
  the skeleton; a Postgres full-text or external-search adapter can implement the
  same behaviour later without touching the query pipeline (constitution
  Principle VI).

  Tenant filtering is a **storage-level guarantee**: `query/3` MUST NOT return
  documents from another tenant. Ranking, authorisation and grouping happen above
  the index.
  """

  alias Apex.Discovery.Search.Document

  @doc "Insert or replace a document by id, honouring apply-if-newer on `source_version`."
  @callback upsert(document :: Document.t()) :: :ok

  @doc "Remove a document by id (idempotent)."
  @callback delete(id :: String.t()) :: :ok

  @doc """
  Return candidate documents already filtered to `tenant_id` and `sources`,
  matching the normalised query. May over-return on relevance (the ranker orders);
  MUST NOT under-return matches within the tenant/sources, nor cross tenants.
  """
  @callback query(tenant_id :: String.t(), sources :: [atom()], normalized_query :: String.t()) ::
              {:ok, [Document.t()]} | {:error, term()}
end
