---
description: "Task list for Global Search implementation"
---

# Tasks: Global Search

**Input**: Design documents from `specs/001-global-search/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: INCLUDED — the project constitution makes boundary/invariant tests
mandatory (tenant isolation, permission redaction, exact-id ranking, idempotent
upserts, fail-safe partial results).

**Organization**: Tasks are grouped by user story. The core neutral structs
(`Scope`, `Document`, `Result`, `Group`, `Response`) already exist under
`lib/apex/discovery/search/` and are not re-created here.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US5 map to the spec's user stories
- Paths are relative to the repository root

---

## Phase 1: Setup

**Purpose**: Establish a known-green baseline before building the pipeline.

- [ ] T001 Confirm baseline compiles and existing struct tests pass (`mix compile && mix test`)
- [ ] T002 [P] Confirm formatting is clean (`mix format --check-formatted`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Contracts, storage, sources and indexing that every user story needs.

**⚠️ CRITICAL**: No user story can be completed until this phase is done.

- [ ] T003 [P] Define the `Source` behaviour (callbacks `source_key/0`, `group_label/0`, `type_weight/0`, `to_document/1`, `fetch_all/1`) in `lib/apex/discovery/search/source.ex` per `contracts/source.md`
- [ ] T004 [P] Define the `Index` behaviour (callbacks `upsert/1`, `delete/1`, `query/3`) in `lib/apex/discovery/search/index.ex` per `contracts/index.md`
- [ ] T005 [P] Implement `Normalizer.normalize/1` (downcase + Unicode NFKD + strip combining marks, folding Latin accents and Arabic diacritics) in `lib/apex/discovery/search/normalizer.ex`
- [ ] T006 [P] Unit tests for `Normalizer` (English case/accents + Arabic diacritics fold symmetrically) in `test/apex/discovery/search/normalizer_test.exs`
- [ ] T007 Implement the in-memory `Index` adapter as a supervised GenServer holding `%{id => Document}` with `upsert/1` (apply-if-newer on `source_version`), `delete/1`, and `query/3` (filter by `tenant_id` + `sources`, substring candidate match on normalized `search_terms`) in `lib/apex/discovery/search/index/in_memory.ex` (depends: T004)
- [ ] T008 Unit tests for the in-memory index: apply-if-newer idempotency (older/equal/newer `source_version`), delete, and tenant/source candidate filtering in `test/apex/discovery/search/index_in_memory_test.exs` (depends: T007)
- [ ] T009 [P] Implement the source `Registry` (map `source_key => module`, `all/0`, `fetch/1`) in `lib/apex/discovery/search/registry.ex` (depends: T003)
- [ ] T010 [P] Implement the Trading Partners source (sample tp_1–tp_3, `required_permissions: []`, `to_document/1`, `fetch_all/1`) in `lib/apex/discovery/search/sources/trading_partners.ex` (depends: T003)
- [ ] T011 [P] Implement the Invoices source (sample inv_123/inv_222/inv_999, `required_permissions: [:finance]`) in `lib/apex/discovery/search/sources/invoices.ex` (depends: T003)
- [ ] T012 [P] Implement the Payment Requests source (sample pr_111/pr_222, `required_permissions: [:payments]`) in `lib/apex/discovery/search/sources/payment_requests.ex` (depends: T003)
- [ ] T013 Implement the `Indexer` (`apply/1` for upsert/delete via `to_document` + `Index`; `reindex/1` backfill via `fetch_all` + upsert) in `lib/apex/discovery/search/indexer.ex` (depends: T007, T003)
- [ ] T014 Unit tests for `Indexer`: backfill converges, and a stale replay cannot regress fresher state (apply-if-newer end-to-end) in `test/apex/discovery/search/indexer_test.exs` (depends: T013)
- [ ] T015 Wire supervision: start the in-memory `Index` in `lib/apex/application.ex` and seed the sample data via `Indexer.reindex/1` for the registered sources (depends: T007, T009–T013)

**Checkpoint**: Sample documents are indexed and retrievable by tenant + source.

---

## Phase 3: User Story 1 - Grouped, tenant-scoped search (Priority: P1) 🎯 MVP

**Goal**: Typing a phrase returns results grouped by object type, confined to the
caller's business.

**Independent Test**: As an `acme` user, search "Gulf" → grouped Trading Partner,
Invoice and Payment Request results for `acme`; no `desert` records.

### Tests for User Story 1

- [ ] T016 [P] [US1] Integration test: acme "Gulf" returns labelled groups (Trading Partners, Invoices, Payment Requests) with acme records only; desert tp_3/inv_999 excluded (spec scenarios 1–2) in `test/apex/discovery/search/search_test.exs`

### Implementation for User Story 1

- [ ] T017 [US1] Implement `Authorizer.filter/2` tenant stage: drop any document whose `tenant_id != scope.business_id` in `lib/apex/discovery/search/authorizer.ex`
- [ ] T018 [US1] Implement `Ranker` basic relevance + `Result` projection (per-field match strength, `matched_fields`, normalized `score`) in `lib/apex/discovery/search/ranker.ex`
- [ ] T019 [US1] Implement `Grouper` (bucket by `source`, order groups by fixed source priority/`type_weight`, attach `group_label`, apply per-group cap 5 and overall limit 10) in `lib/apex/discovery/search/grouper.ex`
- [ ] T020 [US1] Implement `Search.query/3` orchestration (require scope, normalize query, resolve sources via Registry, retrieve candidates, tenant-authorize → rank → group, assemble `Response` with `meta`) in `lib/apex/discovery/search.ex`
- [ ] T021 [US1] Handle empty/blank query → well-formed empty `Response` (edge case) in `lib/apex/discovery/search.ex`

**Checkpoint**: US1 is a working MVP — grouped, tenant-safe search.

---

## Phase 4: User Story 2 - See only what I am authorised to see (Priority: P1)

**Goal**: Per-object-type permission gating; unauthorized results omitted entirely.

**Independent Test**: An `acme` user without `:finance` searches "INV-123" → the
invoice is absent; without `:payments`, no Payment Request results appear.

### Tests for User Story 2

- [ ] T022 [P] [US2] Integration test: no-finance user → invoices omitted; no-payments user → payment requests omitted; finance user → invoices present (spec scenarios 3–4) in `test/apex/discovery/search/authorizer_test.exs`

### Implementation for User Story 2

- [ ] T023 [US2] Extend `Authorizer` with the permission stage: omit any document whose `required_permissions` are not all held by the scope (`Scope.permits?/2`) in `lib/apex/discovery/search/authorizer.ex`
- [ ] T024 [US2] Ensure `Search.query/3` applies the permission stage after the tenant stage in `lib/apex/discovery/search.ex`

**Checkpoint**: US1 + US2 — tenant-safe and permission-safe results.

---

## Phase 5: User Story 3 - Exact identifiers outrank loose matches (Priority: P2)

**Goal**: Exact identifier matches rank above loose text matches; recency breaks ties.

**Independent Test**: An `acme` finance user searches "INV-123" → INV-123 is the
top result, above trading-partner "Gulf" matches.

### Tests for User Story 3

- [ ] T025 [P] [US3] Unit test: exact identifier ("INV-123") outranks name matches; equal relevance → newer `updated_at` wins (spec scenario 5) in `test/apex/discovery/search/ranker_test.exs`

### Implementation for User Story 3

- [ ] T026 [US3] Enhance `Ranker` with layered ordering (exact-identifier band > text relevance > `type_weight` > recency) in `lib/apex/discovery/search/ranker.ex`
- [ ] T027 [US3] Wire the enhanced ranking into `Search.query/3` result ordering in `lib/apex/discovery/search.ex`

**Checkpoint**: Results are usefully ordered, exact-id first.

---

## Phase 6: User Story 4 - Restrict search to specific object types (Priority: P2)

**Goal**: The `:sources` option limits results to the named object types.

**Independent Test**: Search "Gulf" with `sources: [:trading_partners]` → only
Trading Partner results.

### Tests for User Story 4

- [ ] T028 [P] [US4] Integration test: `sources: [:trading_partners]` returns only Trading Partners; an unknown source is handled per the fail-safe policy, not a crash (spec scenario 6) in `test/apex/discovery/search/search_test.exs`

### Implementation for User Story 4

- [ ] T029 [US4] Enforce the `:sources` option when resolving sources (Registry lookup + validation) so only requested, known sources are queried in `lib/apex/discovery/search.ex`

**Checkpoint**: Scoped, filterable search.

---

## Phase 7: User Story 5 - Partial results when a source fails (Priority: P3)

**Goal**: One source failing yields a degraded response, not a total failure.

**Independent Test**: With Payment Requests made to fail, search "Gulf" → Trading
Partner + Invoice groups still returned; `degraded? == true`, `errors` names
`:payment_requests`.

### Tests for User Story 5

- [ ] T030 [P] [US5] Integration test: inject a failing source; healthy groups still return, `degraded? == true`, `errors` records the failed source (spec scenario 7) in `test/apex/discovery/search/search_test.exs`

### Implementation for User Story 5

- [ ] T031 [US5] Implement per-source isolated retrieval in `Search.query/3`: wrap each source's retrieval so a failure is captured into `errors` and sets `degraded?`, while healthy sources proceed in `lib/apex/discovery/search.ex`

**Checkpoint**: All five stories functional and independently testable.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T032 [P] Add the observability seam: generate/propagate a correlation id, emit telemetry-style query events (count, duration, degraded) and an audit event for sensitive searches in `lib/apex/discovery/search/telemetry.ex` (wired from `Search.query/3`)
- [ ] T033 [P] Author `ARCHITECTURE.md` at the repo root (assumptions, goals/non-goals, boundaries, components, contracts, data model, indexing/query flow, security, consistency, observability, testing, rollout) drawing from spec.md/plan.md/research.md
- [ ] T034 [P] Author `DECISIONS.md` at the repo root (trade-offs, rejected alternatives, assumptions, intentional timebox shortcuts, next steps)
- [ ] T035 Update `README.md` at the repo root (what it is, how to run, how to test, sample IEx query)
- [ ] T036 Run the `quickstart.md` validation (all 7 scenarios) and confirm `mix test` is green

---

## Dependencies & Execution Order

- **Setup (Phase 1)** → **Foundational (Phase 2)** blocks everything.
- **US1 (Phase 3)** is the MVP; **US2–US5** each build on the query pipeline US1
  establishes and can otherwise be delivered incrementally in priority order.
- Files shared across stories (`lib/apex/discovery/search.ex`,
  `authorizer.ex`, `ranker.ex`) are edited sequentially — those tasks are **not**
  marked `[P]` across stories.
- **Polish (Phase 8)** after the desired stories are complete.

### Story dependency notes

- US2 extends `Authorizer` (adds the permission stage after US1's tenant stage).
- US3 enhances `Ranker` (US1 created the basic version).
- US4 tightens source selection in `query/3` (US1/foundational default to all).
- US5 wraps retrieval in `query/3` with per-source isolation.

## Parallel Opportunities

- Foundational: T003, T004, T005/T006, T009, T010, T011, T012 are `[P]` (distinct files).
- Each story's test task (`[P]`) can be written before its implementation.
- Polish docs T032/T033/T034 are `[P]` (distinct files).

## Parallel Example: Foundational

```text
# Contracts + normalizer + sources in parallel (different files):
T003 Source behaviour        (source.ex)
T004 Index behaviour         (index.ex)
T005 Normalizer              (normalizer.ex)
T010 Trading Partners source (sources/trading_partners.ex)
T011 Invoices source         (sources/invoices.ex)
T012 Payment Requests source (sources/payment_requests.ex)
```

## Implementation Strategy

### MVP first

1. Phase 1 Setup → Phase 2 Foundational → Phase 3 US1.
2. **Stop and validate**: acme "Gulf" returns grouped, tenant-scoped results; desert excluded.

### Incremental delivery

US1 (MVP) → US2 (permission safety) → US3 (ranking) → US4 (filtering) → US5
(resilience) → Polish (observability + the three deliverable docs).

## Notes

- `[P]` = different files, no incomplete-task dependencies.
- Commit after each task or logical group.
- Verify each story's test fails before implementing it.
- Every story must remain independently testable — avoid cross-story coupling that
  breaks that.
