# Contract: `Index` behaviour

The swappable storage/retrieval seam. The in-memory adapter implements it for the
skeleton; Postgres FTS or an external engine can implement it later without
touching the pipeline (Principle VI).

```elixir
@callback upsert(document :: Apex.Discovery.Search.Document.t()) :: :ok
@callback delete(id :: String.t()) :: :ok
@callback query(tenant_id :: String.t(), sources :: [atom], normalized_query :: String.t()) ::
            {:ok, [Apex.Discovery.Search.Document.t()]} | {:error, term}
```

| Callback | Purpose |
|----------|---------|
| `upsert/1` | Insert or replace by `id`, honouring apply-if-newer on `source_version`. |
| `delete/1` | Remove a document by `id` (idempotent). |
| `query/3` | Return candidate documents already filtered to `tenant_id` and the requested `sources`. Ranking/authz/grouping happen above the index. |

## Rules

- `query/3` MUST NOT return documents from another tenant. Tenant filtering is a
  storage-level guarantee, not left to the caller.
- `query/3` returns **candidates** — it may over-return on relevance (the Ranker
  decides ordering), but MUST NOT under-return matches within the tenant/sources.
- `upsert/1` MUST be idempotent: re-applying the same or older `source_version` is
  a no-op (older) or replace (same/newer), never a duplicate.
- Errors surface as `{:error, reason}` so the query layer can record a per-source
  failure and degrade gracefully rather than crash.

## Skeleton adapter

`Apex.Discovery.Search.Index.InMemory` — a supervised GenServer holding
`%{id => Document}`, plus the apply-if-newer guard. Suitable for tests and the
sample data; not intended for production scale (see research.md §1).
