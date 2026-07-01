# Implementation Plan: Global Search

**Branch**: `001-global-search` | **Date**: 2026-07-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-global-search/spec.md`

## Summary

Global search lets a business user type a phrase and receive grouped, tenant-safe
results across trading partners, invoices and payment requests. Technically it is
a **behaviour of the Discovery context**: source contexts emit domain events that
an **Indexer** projects into neutral `Document`s held in a swappable **Index**;
`Search.query/3` retrieves candidates for the selected sources, an **Authorizer**
enforces tenant + permission scoping, a pure **Ranker** scores them (exact
identifiers first), and a **Grouper** buckets and bounds them into a `Response`.
Reusability comes from two contracts — a `Source` behaviour (how a domain joins)
and an `Index` behaviour (how documents are stored/retrieved). The skeleton is a
plain, supervised Mix project with an in-memory index and three example sources.

## Technical Context

**Language/Version**: Elixir 1.18.3 (Erlang/OTP 26)

**Primary Dependencies**: None beyond the standard library for v1. `:telemetry`
is the intended (deferred) mechanism for metrics/traces; the skeleton emits plain
`Logger` + a thin telemetry seam rather than adding a dependency.

**Storage**: In-memory index for the skeleton (a supervised GenServer holding
`%{id => Document}`), reached only through the `Index` behaviour so it can later be
replaced by Postgres full-text search or an external engine. Owning-context data
is represented by in-process sample sources; there is no database.

**Testing**: ExUnit. Emphasis on boundary/invariant tests (tenant isolation,
permission redaction, exact-id ranking precedence, idempotent upserts, fail-safe
partial results).

**Target Platform**: BEAM. Delivered as an embeddable library/context that a
Phoenix (or other) host would call; no web layer in the skeleton.

**Project Type**: Single project (one Mix app; search lives under
`lib/apex/discovery/search/`).

**Performance Goals**: Interactive latency. The query path reads **only** the
projection and performs **no** cross-domain joins or live source fan-out, giving
predictable latency (target p95 well under one second in a real deployment;
sub-millisecond on the in-memory skeleton).

**Constraints**: No external search engine or database required to run. Search
reads only its own projection (never another context's tables, never the Ledger).
Tenant + permission filtering happen before any result is returned. Ranking and
grouping are deterministic.

**Scale/Scope**: Skeleton indexes the 8 sample records across 3 sources. The
design targets far larger scale by swapping the `Index` adapter; nothing in the
query pipeline assumes the in-memory store.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| # | Principle | Gate | Status |
|---|-----------|------|--------|
| I | Bounded contexts own their data | Search ingests only via `Source` adapters fed by domain events; it never reads source tables. | ✅ PASS |
| II | Search is a read model, not truth | Index is a derived, rebuildable projection; `Search.query/3` is read-only; no state is taken from it as authoritative. | ✅ PASS |
| III | Eventually consistent, stale-aware | Indexing is idempotent + apply-if-newer; backfill/reindex repairs; `indexed_at` exposes lag. | ✅ PASS |
| IV | Tenant isolation + authz before results | `Scope` requires `business_id`; Authorizer filters tenant + permissions before results leave. | ✅ PASS |
| V | Least-disclosure snippets | `Document` carries only scope-safe fields + `required_permissions`; unauthorized results omitted. | ✅ PASS |
| VI | Explicit, reusable contracts | A `Source` behaviour and a swappable `Index` behaviour; new sources register without pipeline changes. | ✅ PASS |
| — | Fail safe | Per-source retrieval isolated; failures recorded in `errors` + `degraded?`, healthy sources still returned. | ✅ PASS |
| — | Predictable latency | Query reads only the projection; no cross-domain joins. | ✅ PASS |
| — | Observability | Correlation id per query; telemetry seam; index lag detectable. | ✅ PASS |
| — | i18n | `Normalizer` folds case + diacritics for Arabic/English on both index and query. | ✅ PASS |

No violations. **Complexity Tracking is empty** (nothing to justify).

## Project Structure

### Documentation (this feature)

```text
specs/001-global-search/
├── plan.md              # This file
├── research.md          # Phase 0 output — key technical decisions
├── data-model.md        # Phase 1 output — entities and relationships
├── quickstart.md        # Phase 1 output — how to run and validate
├── contracts/           # Phase 1 output — interface contracts
│   ├── public-api.md    #   Search.query/3
│   ├── source.md        #   Source behaviour (how a domain joins)
│   ├── index.md         #   Index behaviour (swappable storage)
│   └── events.md        #   Domain-event → indexer contract
└── tasks.md             # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/apex/
├── account.ex            # context facade (owns trading partners)  [exists]
├── billing.ex            # context facade (owns invoices)          [exists]
├── remittance.ex         # context facade (owns payment requests)  [exists]
├── ledger.ex             # context facade (search-deferred)        [exists]
├── discovery.ex          # context facade (owns search)            [exists]
└── discovery/
    └── search/
        ├── scope.ex        # caller authz context        [exists]
        ├── document.ex     # neutral indexed record      [exists]
        ├── result.ex       # output result              [exists]
        ├── group.ex        # results per source         [exists]
        ├── response.ex     # grouped + degraded/errors  [exists]
        ├── source.ex       # @behaviour: Source contract        [new]
        ├── index.ex        # @behaviour: Index contract         [new]
        ├── registry.ex     # source_key => module registry      [new]
        ├── normalizer.ex   # case/diacritics folding (i18n)     [new]
        ├── ranker.ex       # pure scoring (exact-id first)      [new]
        ├── grouper.ex      # bucket + order + limits            [new]
        ├── authorizer.ex   # tenant + permission filter/omit    [new]
        ├── indexer.ex      # event apply (upsert/delete) + backfill [new]
        ├── index/
        │   └── in_memory.ex  # supervised in-memory Index adapter  [new]
        └── sources/
            ├── trading_partners.ex  # Account source + sample data  [new]
            ├── invoices.ex          # Billing source + sample data  [new]
            └── payment_requests.ex   # Remittance source + sample data [new]

lib/apex/discovery/search.ex   # public facade: query/3            [new]

test/apex/discovery/search/
├── structs_test.exs           # struct invariants                 [exists]
├── normalizer_test.exs        # folding                           [new]
├── ranker_test.exs            # exact-id precedence, recency       [new]
├── authorizer_test.exs        # tenant isolation + redaction       [new]
├── indexer_test.exs           # idempotent apply-if-newer, backfill [new]
└── search_test.exs            # end-to-end sample-data scenarios    [new]
```

**Structure Decision**: Single Mix project. Search is a module tree under
`lib/apex/discovery/search/`, keeping the "search is a verb of Discovery" boundary
explicit in the file system. Data structures already exist; Phase 2 adds the
behaviours, pipeline components, in-memory index and example sources.

## Complexity Tracking

> No constitution violations — this table is intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
