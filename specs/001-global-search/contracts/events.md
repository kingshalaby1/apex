# Contract: Domain-event → Indexer

How source contexts keep the projection fresh. In production these are messages on
a bus; in the skeleton they are function calls into the Indexer that model the same
contract.

## Event shape (logical)

```elixir
%{
  type: :upsert | :delete,
  source: atom(),            # e.g. :invoices
  record: term() | nil,      # present for :upsert; the source's record
  id: String.t() | nil       # present for :delete; namespaced document id
}
```

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

- Source contexts publish `InvoiceCreated`, `InvoicePaid`, `TradingPartnerAdded`,
  `PaymentRequestStateChanged`, … onto a bus.
- A durable subscriber translates each into an `apply(event)` call with retries and
  a dead-letter path; `reindex` runs on deploy/backfill.
- The Ledger is **not** a publisher to search in v1 (documented non-goal).
