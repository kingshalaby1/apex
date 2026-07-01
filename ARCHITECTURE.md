# Apex Global Search — Architecture

A reusable global search capability for Apex, a domain-oriented B2B trade and
financing platform. A business user types a phrase (e.g. "Gulf") and receives
useful, **grouped, tenant-safe** results across business objects — trading
partners, invoices, payment requests — with more object types able to join later
without reworking the system.

This document is the design. The companion `DECISIONS.md` records trade-offs and
rejected alternatives; `README.md` explains how to run the skeleton. The governing
principles live in [`.specify/memory/constitution.md`](.specify/memory/constitution.md),
and the feature is specified in [`specs/001-global-search/`](specs/001-global-search/).

---

## 1. Assumptions and questions

**Assumptions made** (documented so they can be confirmed with product/security):

- **Coarse permissions in v1.** Authorisation is *tenant + a coarse, role-style
  permission set* (e.g. `:finance`, `:payments`). This satisfies the sample data.
  Fine-grained per-record ACLs are a non-goal for v1.
- **Redaction = omit.** Results a user may not see are **omitted entirely** (no
  redacted stub or count). Confirmed during clarification.
- **Scope is trusted.** The caller's business and permissions are derived from the
  authenticated session upstream, never from client query input.
- **Eventual consistency is acceptable.** Search reads a derived projection that
  may be slightly stale; owning contexts remain canonical.
- **Ledger is out of scope for search in v1** (see §2).
- **Simple i18n in v1.** Case + diacritics folding for Arabic/English; no stemming,
  synonyms, transliteration.

**Questions a production build would confirm:**

- Exact permission taxonomy and how it maps to object types per business.
- Whether any object type needs record-level sharing (would promote ACLs to v1).
- Audit/retention requirements for search logs (financial-data compliance).
- Expected index size and query volume (drives the storage choice in §12).

## 2. Goals and non-goals

**Goals (v1)**

- One query API returning grouped results across trading partners, invoices,
  payment requests.
- Tenant isolation and permission gating enforced **before** results are returned.
- Deterministic ranking (exact identifiers first) and grouping (fixed order, bounded).
- Reusability: a new object type joins by implementing one contract.
- Fail-safe partial results; the query never becomes a second source of truth.

**Non-goals (deferred, documented)**

- **Ledger as a search source** — no human-searchable name, highest sensitivity,
  and using a stale projection as financial truth is unacceptable. Re-enters later
  as an *enrichment signal* on other results or a *narrow exact-reference lookup*.
- Per-record ACLs, autocomplete/typeahead, ML/learned ranking, cross-business
  discovery, and an external search engine (the design admits all of these later).

## 3. Domain boundaries

Apex is organised into bounded contexts that own their data and expose public
APIs; cross-context access to internal tables is forbidden.

| Context | Owns | Role in search |
|---------|------|----------------|
| **Account** | Business identity, trading-partner relationships | Source (trading partners) |
| **Billing** | Invoices | Source (invoices) |
| **Remittance** | Payment obligations, payment requests | Source (payment requests) |
| **Ledger** | Append-only accounting entries | **Not a v1 source** (non-goal) |
| **Discovery** | Derived read-side projections | **Owns search** |

**Search is a behaviour (verb) of Discovery**, not a context of its own. Source
contexts emit domain events; Discovery projects them into a neutral index and
serves queries over that index. Discovery reads **only its own projection** —
never another context's tables, never the Ledger. This keeps every context
independently extractable (constitution Principle I).

## 4. Components

All under `lib/apex/discovery/search/`.

| Component | Responsibility |
|-----------|----------------|
| `Search` (`search.ex`) | Public façade `query/3`: orchestrates the pipeline, returns a `Response`. |
| `Scope` | Caller authorisation context (tenant + permissions). |
| `Document` | Neutral indexed record (the projection unit). |
| `Result` / `Group` / `Response` | Output shapes; `Response` carries `degraded?`/`errors`. |
| `Source` (behaviour) | Contract a domain implements to become searchable. |
| `Index` (behaviour) | Swappable storage/retrieval contract. |
| `Index.InMemory` | Skeleton index: supervised GenServer, apply-if-newer. |
| `Registry` | `source_key => module` map of known sources. |
| `Indexer` | Applies events (upsert/delete) and backfills (`reindex`, `seed`). |
| `Normalizer` | Case/diacritics folding for Arabic/English. |
| `Authorizer` | Tenant + permission filtering (omit-on-deny). |
| `Ranker` | Pure scoring; exact identifiers first. |
| `Grouper` | Bucket by source, fixed order, bounded. |
| `Telemetry` | Observability seam (correlation id, query signal, audit). |

## 5. Public contracts

Three explicit seams make the design reusable and swappable (contracts detailed in
[`specs/001-global-search/contracts/`](specs/001-global-search/contracts/)).

**Query API** — `Apex.Discovery.Search.query(scope, text, opts)` → `%Response{}`.
Always returns; source failures degrade rather than raise.

**`Source` behaviour** — how a domain joins:
`source_key/0`, `group_label/0`, `type_weight/0`, `to_document/1`, `fetch_all/1`.
A new object type is a module + a one-line `Registry` entry; the pipeline is
untouched (Principle VI).

**`Index` behaviour** — swappable storage: `upsert/1`, `delete/1`, `query/3`.
`Index.InMemory` today; Postgres FTS / OpenSearch behind the same contract later.

## 6. Data model

The neutral `Document` is the unit every source produces and the index stores:

- `id` — namespaced, globally unique (`"invoice:inv_123"`) → idempotent upsert key.
- `source`, `tenant_id` (first-class), `title`, `subtitle`.
- `required_permissions` — the gate for redaction/omission.
- `search_terms` — `field => text`, drives `matched_fields` and exact-id ranking.
- `metadata` — scope-safe extras only.
- `url`, `updated_at` (recency), `source_version` (apply-if-newer), `indexed_at`.

A document holds **only** fields safe for anyone permitted to see the record —
nothing sensitive is stored "for later filtering". Full field rules and the
sample-data mapping are in
[`data-model.md`](specs/001-global-search/data-model.md).

## 7. Indexing flow

```
Source context ──event──▶ Indexer.apply ──to_document──▶ Index.upsert (apply-if-newer)
Source.fetch_all ──────── Indexer.reindex (backfill) ──▶ Index.upsert
```

- **Initial indexing / backfill** — `Indexer.reindex(source, tenant)` pulls
  `fetch_all/1` and upserts each record. The skeleton seeds all sources for the
  sample tenants at startup (`Indexer.seed/0`).
- **Updates / deletes** — `apply(%{type: :upsert|:delete, ...})`.
- **Idempotency** — the namespaced `id` makes upserts non-duplicating; the
  `source_version` "apply-if-newer" guard makes them monotonic, so retries,
  out-of-order events and a backfill overlapping live events converge without
  regressing fresher state.
- **Retries** — in production the event subscriber retries with a dead-letter path;
  because writes are idempotent, retries are safe.

## 8. Query flow

```
query(scope, text, opts)
  → normalise text
  → resolve sources (Registry; unknown → recorded error)
  → retrieve candidates PER SOURCE (isolated; a failure degrades, not crashes)
  → Authorizer: tenant filter, then permission filter (omit-on-deny)
  → Ranker: score + order (exact-id band > relevance > type weight > recency)
  → Grouper: bucket by source, fixed order, per-group cap 5, overall limit 10
  → Response{groups, degraded?, errors, meta{correlation_id, took_ms, ...}}
```

Validation: a `Scope` cannot be built without a `business_id`, so no query runs
untenanted. A blank query returns a well-formed empty response.

## 9. Security

- **Tenant isolation** at two layers: the index filters by `tenant_id`, and the
  `Authorizer` re-checks it (defence in depth). No cross-business result is ever
  returned (constitution Principle IV).
- **Permission gating** — each document declares `required_permissions`; the
  `Authorizer` omits any the scope does not fully hold (`Scope.permits?/2`).
- **Least disclosure** — documents contain only scope-safe fields, so snippets
  cannot leak private/internal data (Principle V).
- **Audit** — the telemetry seam records who searched within which business and
  is where result-click auditing attaches.

## 10. Consistency

- Search is a **read model, never a source of truth** (Principle II). No decision
  or balance is taken from the index.
- Cross-context data is **eventually consistent**; results may be slightly stale.
  `indexed_at` exposes lag.
- **Repair** — the projection is rebuildable from source at any time via backfill;
  it is safe to discard and rebuild. Idempotent apply-if-newer makes reconciliation
  convergent.

## 11. Observability

- Every query carries a **correlation id** (generated if absent) surfaced in
  `Response.meta` for end-to-end tracing.
- The `Telemetry` seam emits a query-completed signal (result count, duration,
  `degraded?`) — the attach point for `:telemetry`/metrics and dashboards.
- **Operational signals**: index lag (`indexed_at`), failed indexing jobs
  (event subscriber), and degraded queries (`degraded?` + `errors`) are all
  detectable.

## 12. Testing strategy

Boundary and invariant tests are mandatory (constitution). The suite covers:

| Area | Test |
|------|------|
| i18n normalisation | `normalizer_test.exs` (Latin accents, Arabic diacritics, symmetry) |
| Index idempotency | `index_in_memory_test.exs` (apply-if-newer, delete, tenant/source filter) |
| Backfill / reconcile | `indexer_test.exs` (converges; stale replay can't regress) |
| Tenant + permission | `authorizer_test.exs` (isolation, omit-on-deny) |
| Ranking | `ranker_test.exs` (exact-id precedence, recency tiebreak) |
| End-to-end scenarios | `search_test.exs` (all seven sample-data scenarios incl. fail-safe) |

Contract tests live implicitly in the source/index behaviours plus the
sample-data end-to-end tests. `quickstart.md` maps every scenario to a test.

## 13. Rollout plan

1. **Skeleton (here)** — in-memory index, three sources, full pipeline + tests.
2. **Wire real sources** — implement `Source` adapters in Account/Billing/Remittance
   over their public read APIs; keep the sample sources as fixtures.
3. **Event ingestion** — subscribe the `Indexer` to the domain-event bus with
   retries + dead-letter; add deploy-time backfill.
4. **Durable index** — implement the `Index` behaviour over Postgres full-text
   search (single-node, no new infra); the pipeline is unchanged.
5. **Scale/relevance** — move to an external engine (OpenSearch) or hybrid/AI
   retrieval behind the same `Index` behaviour if volume/relevance demands it.
6. **Broaden sources** — add object types (and, if justified, Ledger as an
   enrichment signal or exact-reference lookup) by implementing `Source`.

Each step is shippable and reversible; the public API and contracts stay stable
throughout.
