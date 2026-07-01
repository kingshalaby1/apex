defmodule Apex.Discovery.Search.Indexer do
  @moduledoc """
  Keeps the search projection in sync with the source contexts.

  In production this subscribes to domain events on a bus; in the skeleton the same
  contract is exercised through direct calls:

    * `apply/2` — project a single change (`:upsert` / `:delete`).
    * `reindex/3` — backfill a source for a tenant (`fetch_all` → `to_document` →
      upsert). Safe to run anytime.
    * `seed/1` — backfill every registered source for the sample tenants.

  All writes go through the index's apply-if-newer `upsert/1`, so replays, retries
  and backfill overlapping live events converge without regressing fresher state
  (constitution Principle III).
  """

  alias Apex.Discovery.Search.{Index.InMemory, Registry}

  @sample_tenants ~w(acme desert)

  @doc """
  Apply a change event to the index.

  Events: `%{type: :upsert, source: key, record: record}`,
  `%{type: :delete, source: key, record: record}`, or
  `%{type: :delete, id: namespaced_id}`.
  """
  @spec apply(map(), module()) :: :ok
  def apply(event, index \\ InMemory)

  def apply(%{type: :upsert, source: key, record: record}, index) do
    case Registry.module(key) do
      nil -> {:error, {:unknown_source, key}}
      mod -> InMemory.upsert(index, mod.to_document(record))
    end
  end

  def apply(%{type: :delete, source: key, record: record}, index) do
    case Registry.module(key) do
      nil -> {:error, {:unknown_source, key}}
      mod -> InMemory.delete(index, mod.to_document(record).id)
    end
  end

  def apply(%{type: :delete, id: id}, index) do
    InMemory.delete(index, id)
  end

  @doc "Backfill one source for one tenant."
  @spec reindex(module(), String.t(), module()) :: :ok
  def reindex(source_mod, tenant_id, index \\ InMemory) do
    for record <- source_mod.fetch_all(tenant_id) do
      InMemory.upsert(index, source_mod.to_document(record))
    end

    :ok
  end

  @doc "Backfill all registered sources for the sample tenants (skeleton seeding)."
  @spec seed(module()) :: :ok
  def seed(index \\ InMemory) do
    for source_mod <- Registry.all(), tenant_id <- @sample_tenants do
      reindex(source_mod, tenant_id, index)
    end

    :ok
  end
end
