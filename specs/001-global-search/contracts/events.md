# Contract: Domain-event → Indexer

How source contexts keep the projection fresh. Source contexts publish domain
events on `Apex.EventBus` (a `Registry`-backed pub/sub); Discovery's
`EventSubscriber` consumes them and calls the `Indexer`. The contexts never
reference search.

## Event shapes

**Published by a context** (domain event, per-source topic):

```elixir
# topic: the source key, e.g. :invoices
%{name: :created | :updated | :deleted, record: term()}
```

**Consumed by the Indexer** (after the subscriber maps domain → index op):

```elixir
%{type: :upsert, source: atom(), record: term()}          # created / updated
%{type: :delete, source: atom(), record: term()}          # deleted (id derived from record)
%{type: :delete, id: String.t()}                          # deleted (by namespaced id)
```

The `EventSubscriber` is where `:created`/`:updated` become `:upsert` and
`:deleted` becomes `:delete` — keeping the domain→index mapping on the search side.

## Indexer operations

| Operation | Effect |
|-----------|--------|
| `apply(event)` | `:upsert` → `source.to_document(record)` then `Index.upsert/1` (apply-if-newer); `:delete` → `Index.delete(id)`. |
| `reindex(source, tenant_id)` | Backfill: `source.fetch_all(tenant_id)` → `to_document` → `upsert` for each. Safe to run anytime. |

## Guarantees

- **Idempotent**: replaying the same event, or a backfill overlapping live events,
  converges to the correct state and never regresses fresher data (apply-if-newer).
- **Repairable**: the index can be discarded and rebuilt entirely via `reindex`
  (Principle II — projection, not truth).
- **Ordering-tolerant**: out-of-order upserts resolve by `source_version`.

## Mapping to real infrastructure (future)

- The skeleton's `Apex.EventBus` (Registry-backed, single node, async) becomes
  `Phoenix.PubSub` or a durable broker behind the same `subscribe/2` + `publish/2`
  wrapper — no caller changes.
- The subscriber gains retries and a dead-letter path; `reindex`/`seed` run on
  deploy/backfill.
- Contexts emit richer domain events (`InvoicePaid`, `TradingPartnerVerified`, …);
  the subscriber decides which map to upserts/deletes.
- The Ledger is **not** a publisher to search in v1 (documented non-goal).
