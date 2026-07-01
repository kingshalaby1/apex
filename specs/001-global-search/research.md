# Phase 0 Research: Global Search

Key technical decisions for the skeleton, each as Decision / Rationale /
Alternatives. There were no unresolved `NEEDS CLARIFICATION` items after
`/speckit-clarify`; this document records the deliberate engineering choices the
plan depends on.

## 1. Index storage: in-memory GenServer behind an `Index` behaviour

**Decision**: Store documents in a supervised GenServer holding `%{id => Document}`,
reached only through an `Index` behaviour (`upsert/1`, `delete/1`,
`query/3`). Candidate retrieval filters by `tenant_id` and `source`, then returns
matching documents for the Ranker to score.

**Rationale**: The assignment forbids requiring Postgres/an external engine, and
the sample set is tiny — a map scan is more than enough and keeps the skeleton
dependency-free. Hiding it behind a behaviour means the store is swappable
(Principle VI) without touching the query pipeline.

**Alternatives**:
- *ETS* — great for concurrency/scale but adds ceremony the skeleton doesn't need;
  noted as the natural next step for a bigger in-node index.
- *Postgres FTS / OpenSearch* — the real production targets; explicitly out of
  scope to run, but the `Index` behaviour is the seam that admits them later.

## 2. Ingestion: idempotent, apply-if-newer upserts via an Indexer

**Decision**: The Indexer converts a source record to a `Document` (via the
source's `to_document/1`) and upserts it keyed by the **namespaced id**
(`"invoice:inv_123"`). An upsert is applied **only if** its `source_version` is
≥ the stored version. Deletes remove by id. `reindex/1` (backfill) pulls
`fetch_all/1` from a source and upserts each record.

**Rationale**: Events can arrive out of order, be retried, or race with a backfill
(Principle III). A namespaced id makes upserts idempotent (no duplicates); the
version guard makes them monotonic (a late/stale write can't regress fresh state).
This is the property that lets backfill run anytime, safely.

**Alternatives**:
- *Last-write-wins by arrival* — simpler but corrupts state under reordering.
- *Full rebuild on every change* — correct but wasteful; backfill is kept for
  repair, not steady state.

## 3. Query execution: per-source isolation for fail-safe partial results

**Decision**: `Search.query/3` resolves the selected sources from the Registry,
then retrieves candidates **per source**, each wrapped so a failure is caught and
recorded as `%{source: key, reason: ...}` while other sources proceed. The
`Response` sets `degraded?: true` and lists `errors`; healthy groups still return.

**Rationale**: A single source failing must not fail the whole query (spec FR-014,
constitution "fail safe"). Isolating retrieval per source is the simplest honest
way to guarantee that, and it makes the failure observable rather than silent.

**Alternatives**:
- *All-or-nothing* — rejected outright; violates the fail-safe principle.
- *Concurrent Task fan-out with timeouts* — the right production shape (and easy to
  add later); the skeleton keeps it sequential for clarity, noting timeouts as the
  extension point.

## 4. Ranking: layered ordering with exact identifiers first

**Decision**: Rank by a composite ordering, most significant first:
1. **Exact identifier match** — query equals a normalized identifier field
   (invoice number, payment-request number, trading-partner UNN) → top band.
2. **Text relevance** — best per-field match strength: `exact (1.0) > prefix (0.7)
   > substring (0.4)` across searchable fields; matched fields are recorded.
3. **Source/type weight** — a fixed per-source weight.
4. **Recency** — newer `updated_at` breaks remaining ties.

The exposed `score` is a normalized float, but ordering is defined by the layered
key so exact-id precedence (FR-007) is guaranteed regardless of score tuning.

**Rationale**: The sample data requires "INV-123 outranks loose Gulf matches"
deterministically. Encoding exact-id as the dominant sort key makes that a
structural guarantee, not a weight-tuning accident. The Ranker is a **pure
function** so it is trivially testable.

**Alternatives**:
- *Single weighted sum* — fragile: a heavy name match could overtake an exact id.
- *ML/learned ranking* — explicit non-goal for v1.

## 5. Grouping: fixed source-priority order, bounded

**Decision**: Group results by `source`, order groups by a **fixed source
priority** (type weight; e.g. Trading Partners → Invoices → Payment Requests),
apply a **per-group cap of 5** and an **overall limit of 10** (caller-overridable).

**Rationale**: Clarified decision — deterministic ordering is predictable for
users and tests (FR-018, FR-009). Fixed order avoids the "groups jump around per
query" problem of score-based ordering.

**Alternatives**: score-based group ordering (rejected: non-deterministic).

## 6. Normalization (i18n): case + diacritics folding

**Decision**: `Normalizer.normalize/1` lower-cases, applies Unicode normalization
(NFKD), and strips combining marks — folding Latin accents and Arabic diacritics
(tashkīl). The same function is applied to indexed `search_terms` and to the query
so matching is symmetric.

**Rationale**: The design must acknowledge Arabic and English names (spec FR-015).
Case/diacritics folding is the high-value, low-cost core; applying it identically
on both sides is what makes matches symmetric.

**Alternatives / deferred**: stemming, synonym expansion, Arabic alef/hamza
normalization, and transliteration — noted as future work, out of scope for v1.

## 7. Authorization: tenant filter + coarse permission gate, omit-on-deny

**Decision**: The Authorizer drops any document whose `tenant_id` ≠
`scope.business_id`, then drops any document whose `required_permissions` are not
all held by the scope (`Scope.permits?/2`). Denied results are **omitted
entirely** (no stub). Only scope-safe fields (already the only fields in the
document) are projected into `Result`.

**Rationale**: Tenant isolation and least-disclosure are non-negotiable
(Principles IV, V). Coarse role-style permissions satisfy the sample data; omit
(clarified) is the simplest leak-free policy.

**Alternatives**: per-record ACLs (deferred, v2); redacted stubs (deferred).

## 8. Observability seam

**Decision**: Each query carries a correlation id (generated if absent). The
pipeline emits telemetry-style events (`[:apex, :search, :query]` with
count/duration/degraded, and an audit event for sensitive searches) through a thin
internal seam that logs in the skeleton.

**Rationale**: Index lag, failed jobs and sensitive searches must be detectable
(constitution Observability). A seam keeps the skeleton dependency-free while
naming exactly where `:telemetry` and an audit sink attach.

**Alternatives**: adding `:telemetry` now (deferred — not needed to prove design).
