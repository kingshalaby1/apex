# Decisions, Trade-offs and Rejected Alternatives

Why the design looks the way it does — the choices that mattered, what was
rejected, and what was deliberately left out given the timebox.

## Key decisions

### 1. Search is a projection owned by Discovery — never reads source tables

**Decision.** Source contexts emit events; Discovery projects them into a neutral
index and queries only that index.

**Why.** Preserves bounded-context boundaries and keeps latency predictable (no
cross-domain joins at query time). The alternative — a federated query that fans
out to each context live — was **rejected**: it couples search to every context's
internals, makes latency the sum of the slowest domain, and pressures the
"no reaching into internal tables" rule.

### 2. Ledger is not a search source in v1

**Decision.** Exclude the Ledger from global search.

**Why.** It has no human-searchable name (entries reference other objects by id),
it is the most sensitive financial data, and it *is* the financial source of
truth — letting a stale projection stand in for it would violate "search is not a
second source of truth". **Rejected** the tempting shortcut of "index everything";
Ledger re-enters later as an enrichment signal or a narrow exact-reference lookup.

### 3. Idempotent, apply-if-newer indexing

**Decision.** Upsert by namespaced id, applying a write only if its
`source_version` is ≥ the stored one.

**Why.** Events reorder, retry, and race with backfill. This makes the index
convergent and backfill safe to run anytime. **Rejected** last-write-wins by
arrival (corrupts under reordering) and full-rebuild-on-every-change (wasteful).

### 4. Layered ranking with exact identifiers first

**Decision.** Order by `{exact-id?, relevance, type weight, recency}` rather than a
single weighted sum.

**Why.** "INV-123 must beat loose Gulf matches" becomes a *structural* guarantee,
not a weight-tuning accident. **Rejected** a single weighted score (fragile — a
strong name match could overtake an exact id) and ML ranking (out of scope).

### 5. Fixed group ordering, bounded results

**Decision.** Groups ordered by fixed source priority; per-group cap 5, overall
limit 10 (clarified defaults).

**Why.** Deterministic and predictable for users and tests. **Rejected**
score-based group ordering (groups jump around per query, hard to test).

### 6. Omit-on-deny redaction

**Decision.** Results the caller may not see are omitted entirely.

**Why.** Simplest leak-free policy; a stub still reveals that a record exists.
**Rejected** (deferred) redacted stubs and count-only summaries.

### 7. Swappable index behind a behaviour; in-memory for the skeleton

**Decision.** An `Index` behaviour with a GenServer-backed in-memory adapter.

**Why.** Runs with zero external dependencies while keeping Postgres FTS / external
search a drop-in later. **Rejected** (for now) ETS (needless ceremony at this size)
and standing up Postgres (explicitly unnecessary to prove the design).

### 8. Coarse permissions, tenant + role set

**Decision.** Authorise on `business_id` + a permission `MapSet` (finance/payments).

**Why.** Fully satisfies the sample data and keeps the model legible. **Rejected**
(deferred) per-record ACLs — real, but a v2 concern that would need product/security
input.

## Assumptions (confirm in production)

- Scope (business + permissions) comes from the authenticated session, not the client.
- Coarse permission taxonomy maps cleanly to object types.
- Slight index staleness is acceptable; owning contexts stay canonical.
- Arabic/English case+diacritics folding is enough for v1 matching.

## Intentional timebox shortcuts

- **In-memory index + in-process sample data** instead of a database — each source
  context (Account/Billing/Remittance) owns its model and a public read API
  (`list_*`), and the search adapters map + delegate to it; only the underlying
  data store is stubbed with in-process sample records.
- **Sequential per-source retrieval** rather than concurrent `Task` fan-out with
  timeouts (the production shape) — clearer, and the fail-safe seam is the same.
- **Logger-based telemetry seam** rather than wiring `:telemetry` and an audit sink.
- **Simple normalisation** (case/diacritics) rather than stemming/synonyms/transliteration.
- **Skeleton URLs** are illustrative strings, not resolved against a router.

## What I would do next with more time

1. Concurrent, timeout-bounded per-source retrieval.
2. Real `Source` adapters over Account/Billing/Remittance public APIs + event
   subscription with retries and a dead-letter queue.
3. A Postgres full-text `Index` adapter (same behaviour) + deploy-time backfill.
4. `:telemetry` metrics, tracing and an audit sink; index-lag dashboards.
5. Richer relevance (prefix/fuzzy, per-field weights) and Arabic alef/hamza
   normalisation.
6. Evaluate Ledger as an enrichment signal on invoice/payment results.
