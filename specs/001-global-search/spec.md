# Feature Specification: Global Search

**Feature Branch**: `001-global-search`

**Created**: 2026-07-01

**Status**: Draft

**Input**: User description: "Global search for Apex — a single search bar at the top of the app where a business user types a phrase (e.g. \"Gulf\") and gets useful, grouped results across multiple business objects: Trading Partners, Invoices, and Payment Requests (with more source types added later without reworking the system)."

## Clarifications

### Session 2026-07-01

- Q: When a user lacks permission for an object type, how are matching results handled? → A: **Omit entirely** — unauthorized results are absent from the response (no redacted stub or count).
- Q: In what order do result groups appear? → A: **Fixed source priority** by object-type weight (e.g. Trading Partners, Invoices, Payment Requests), independent of per-query scores.
- Q: What default result limits apply when the caller does not specify one? → A: **Overall limit 10, per-group cap 5.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find records across object types from one search bar (Priority: P1)

A business user types a phrase (e.g. "Gulf") into a single global search bar and
receives useful results **grouped by object type** — Trading Partners, Invoices,
Payment Requests — each result showing a readable title and subtitle (e.g.
"INV-123 — Gulf Trading"). Results are always confined to the user's current
business.

**Why this priority**: This is the core value and the minimum viable product. One
search box that spans multiple business objects, correctly scoped to the user's
business, is the entire reason the feature exists. Without it there is nothing.

**Independent Test**: Sign in as an `acme` user, search "Gulf", and confirm the
response contains grouped Trading Partner, Invoice, and Payment Request results
that belong to `acme` and none that belong to `desert`.

**Acceptance Scenarios**:

1. **Given** an `acme` user, **When** they search "Gulf", **Then** they see
   grouped results including Trading Partners "Gulf Trading" (tp_1) and "Gulf LLC"
   (tp_2), Invoices INV-123 and INV-222, and Payment Requests 111 and 222.
2. **Given** an `acme` user, **When** they search "Gulf", **Then** they do **not**
   see `desert`'s Trading Partner (tp_3), Invoice (inv_999), or any `desert`
   record.
3. **Given** a `desert` user, **When** they search "Gulf", **Then** they see only
   `desert`-visible results and never `acme`'s invoices or payment requests.
4. **Given** any user, **When** results are returned, **Then** each result is
   presented within a labelled group (e.g. "Trading Partners", "Invoices",
   "Payment Requests") with a title and subtitle.

---

### User Story 2 - See only what I am authorised to see (Priority: P1)

Within their business, a user sees only the object types their permissions allow.
A user without finance permission does not see invoices; a user without payments
permission does not see payment requests. Snippets never expose fields the user is
not entitled to.

**Why this priority**: Tenant isolation and permission enforcement are
non-negotiable. Financial records are sensitive; surfacing a record — or a snippet
field — to someone not entitled to it is a critical failure, so this ships
alongside P1 search.

**Independent Test**: As an `acme` user **without** finance permission, search
"INV-123" and confirm the invoice is not present in results (or appears only as a
safely redacted entry per the agreed policy).

**Acceptance Scenarios**:

1. **Given** an `acme` user without finance permission, **When** they search
   "INV-123", **Then** the invoice is omitted from results.
2. **Given** an `acme` user without payments permission, **When** they search
   "Gulf", **Then** no Payment Request results are returned.
3. **Given** an `acme` user with finance permission, **When** they search "Gulf",
   **Then** invoices INV-123 and INV-222 are included.
4. **Given** any returned result, **When** it is displayed, **Then** it contains
   only fields marked safe for the user's scope (no private or internal-only data).

---

### User Story 3 - Exact identifiers outrank loose text matches (Priority: P2)

When a user searches for a specific identifier (e.g. "INV-123"), the exact record
appears at the top, ahead of records that merely share a word (e.g. trading
partners named "Gulf"). Ranking also reflects text relevance, object-type
weighting, and recency, and results are capped by sensible limits.

**Why this priority**: Correct ranking is what makes search *useful* rather than
merely functional. Once results are correctly scoped (P1), ordering them so the
obviously-intended record wins is the next most valuable improvement.

**Independent Test**: As an `acme` finance user, search "INV-123" and confirm
Invoice INV-123 is the top result, ranked above any trading-partner matches.

**Acceptance Scenarios**:

1. **Given** an `acme` finance user, **When** they search "INV-123", **Then**
   Invoice INV-123 is the highest-ranked result.
2. **Given** more matches exist than the result limit, **When** results are
   returned, **Then** the number of results respects a per-group cap and an overall
   limit.
3. **Given** two records of equal text relevance, **When** they are ranked,
   **Then** the more recently updated record ranks higher.

---

### User Story 4 - Restrict search to specific object types (Priority: P2)

A user (or a UI surface) can limit a search to specific object types, e.g. only
Trading Partners, and receive results only from those types.

**Why this priority**: A useful convenience and a building block for contextual
search surfaces. Valuable but not required for the core experience.

**Independent Test**: Search "Gulf" restricted to Trading Partners only and
confirm the response contains Trading Partner results and no invoices or payment
requests.

**Acceptance Scenarios**:

1. **Given** an `acme` user, **When** they search "Gulf" restricted to Trading
   Partners, **Then** only Trading Partner results are returned.
2. **Given** a source filter naming an unknown or unavailable object type,
   **When** the search runs, **Then** the request is handled per the documented
   safe-failure policy (see User Story 5) rather than returning wrong-type results.

---

### User Story 5 - Get partial results when a source is unavailable (Priority: P3)

If one object type's data is temporarily unavailable or errors, the user still
receives results from the healthy object types, and the response clearly signals
that it is partial/degraded rather than failing the whole search.

**Why this priority**: Resilience. It improves reliability under partial failure
but is only meaningful once the core multi-source search exists.

**Independent Test**: Simulate the Payment Requests source failing, search "Gulf",
and confirm Trading Partner and Invoice groups still return while the response
indicates a degraded state naming the failed source.

**Acceptance Scenarios**:

1. **Given** the Payment Requests source is unavailable, **When** an `acme` user
   searches "Gulf", **Then** Trading Partner and Invoice results are still
   returned.
2. **Given** a source failed during a search, **When** the response is returned,
   **Then** it is marked degraded and records which source(s) failed.
3. **Given** all selected sources fail, **When** the search runs, **Then** the
   response is an explicit degraded/empty result, not an unhandled error.

---

### Edge Cases

- **Empty or whitespace-only query**: returns no results (or an empty response)
  without error.
- **No matches**: returns an empty, well-formed response, not an error.
- **Arabic and English names**: a search behaves sensibly across both scripts;
  differences of case and diacritics do not prevent an obvious match.
- **Result flooding**: a very common term still returns a bounded, ranked set
  (per-group cap + overall limit), never an unbounded list.
- **Recently changed record**: because results come from a derived, slightly-stale
  view, a very recent change may not be reflected immediately; the system must not
  present results as authoritative real-time truth.
- **User with no relevant permissions**: returns an empty (or fully redacted)
  response for gated object types, never a leak.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a search request consisting of a caller
  scope (current business and permissions), a query phrase, an optional list of
  object types to search, and an optional result limit.
- **FR-002**: The system MUST return results **grouped by object type**, each
  group carrying a human-readable label, and each result carrying a title,
  optional subtitle, a link to the record, a relevance score, and the fields that
  matched.
- **FR-003**: The system MUST restrict every result to the caller's current
  business; a record belonging to another business MUST NEVER be returned.
- **FR-004**: The system MUST NOT run a search without a business scope (no
  untenanted queries).
- **FR-005**: The system MUST enforce permission gating per object type: results
  the caller is not permitted to see MUST be **omitted entirely** from the
  response — no redacted stub, count, or other trace of their existence.
- **FR-006**: Result snippets MUST expose only fields that are safe for the
  caller's scope; private or internal-only data MUST NOT appear.
- **FR-007**: An exact match on a record's identifier MUST rank above loose text
  matches on other records.
- **FR-008**: Ranking MUST combine exact-identifier matches, text relevance,
  object-type weighting, and recency into a single ordering.
- **FR-009**: The system MUST bound results by a per-group cap and an overall
  limit, defaulting to an **overall limit of 10 and a per-group cap of 5** when
  the caller does not specify a limit.
- **FR-010**: The system MUST allow a search to be restricted to a specified
  subset of object types.
- **FR-011**: The system MUST treat search as read-only over a derived view and
  MUST NOT be relied upon as a source of truth; owning contexts remain canonical.
- **FR-012**: The searchable view MUST be rebuildable from source at any time
  (full re-index/backfill) and MUST tolerate being discarded and rebuilt.
- **FR-013**: Index updates MUST be idempotent and apply-if-newer, so repeated or
  out-of-order updates cannot corrupt or regress a record's indexed state.
- **FR-014**: If one selected source fails or is unavailable, the system MUST
  return results from the healthy sources and MUST mark the response degraded,
  recording which source(s) failed.
- **FR-015**: Matching MUST behave sensibly for Arabic and English names,
  applying consistent case and diacritics normalization to both indexed terms and
  queries (a simple normalization is acceptable for the first version).
- **FR-016**: The system MUST make sensitive searches and result interactions
  observable/auditable where appropriate (who searched, within which business),
  and MUST make index lag and failed indexing detectable.
- **FR-017**: A new searchable object type MUST be able to join the search without
  changing the behaviour of existing searches or the shared query/ranking/grouping
  logic.
- **FR-018**: Result groups MUST be ordered by a fixed source priority
  (object-type weight) that is independent of per-query scores, so group ordering
  is deterministic.

### Key Entities *(include if feature involves data)*

- **Search Scope**: the caller's authorisation context — the current business
  (mandatory tenant key), the user identity (for audit), and the set of
  permissions held (e.g. finance, payments). Determines what may be seen.
- **Search Query**: the phrase to search, an optional set of object types to
  restrict to, and an optional result limit, evaluated within a Scope.
- **Searchable Record**: a neutral, read-only representation of a business object
  made searchable — object type, identifier, tenant, the permissions required to
  view it, the text that can match, safe snippet/metadata fields, a link, a
  last-updated time, and a version for idempotent updates.
- **Result**: a scope-safe view of a searchable record — object type, identifier,
  title, subtitle, link, score, matched fields, and safe metadata.
- **Result Group**: results for a single object type, with a display label.
- **Object Type (Source)**: a category of searchable record. Version one:
  Trading Partners, Invoices, Payment Requests. Ledger entries are out of scope
  (see Assumptions).
- **Business (Tenant)**: the isolation boundary; every record and query belongs to
  exactly one business.
- **Permission**: a coarse, role-style grant (e.g. finance, payments) that gates
  access to object types.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user searching a common phrase receives results grouped by object
  type, with each group clearly labelled and each result showing a title and
  subtitle.
- **SC-002**: In 100% of searches, no record from another business appears in the
  results (zero cross-tenant leakage).
- **SC-003**: In 100% of searches, no object type the user lacks permission for
  appears in the results, and no unsafe field appears in any snippet.
- **SC-004**: When a user searches an exact identifier that exists in their
  business and scope, that record is the top-ranked result in 100% of cases.
- **SC-005**: When one source is unavailable, the search still returns results
  from all healthy sources and the response is marked degraded, naming the failed
  source(s) — in 100% of such cases.
- **SC-006**: A search restricted to a subset of object types returns results only
  from those types in 100% of cases.
- **SC-007**: Search results are returned quickly enough to feel instant for an
  interactive search bar (target: 95th-percentile response well under one second
  for a typical query), with predictable latency that does not depend on scanning
  multiple domains at query time.
- **SC-008**: A new searchable object type can be added and made searchable
  without modifying the shared query, ranking, or grouping behaviour (verified by
  adding a source through the defined extension point only).

## Assumptions

- **Coarse permissions in v1**: authorisation uses tenant + a coarse,
  role-style permission set (e.g. finance, payments), which fully satisfies the
  sample data. Fine-grained per-record access control lists are a non-goal for v1
  and would require product/security confirmation.
- **Redaction policy** *(confirmed 2026-07-01)*: when a user lacks permission for
  an object type, matching results are **omitted entirely** from the response in
  v1 (no redacted stub or count). The stub alternative is deferred.
- **Ledger out of scope for v1**: ledger entries are excluded from global search
  because they have no human-searchable name, are the most sensitive financial
  data, and using a slightly-stale search view as financial truth is unacceptable.
  Ledger may re-enter later as an enrichment signal on other results or a narrow
  exact-reference lookup.
- **Scope is trusted input**: the caller's business and permissions are derived
  from the authenticated session upstream, never from client-supplied query input.
- **Eventual consistency accepted**: search reads a derived view that may be
  slightly stale; small indexing lag is acceptable and owning contexts remain the
  source of truth.
- **Simple normalization in v1**: Arabic/English handling uses straightforward
  case and diacritics folding; advanced linguistic analysis (stemming, synonyms,
  transliteration) is deferred.
- **Out of scope for v1**: autocomplete/typeahead, machine-learned or heavily
  tuned relevance, and cross-business discovery.
- **Sample data**: the `acme`/`desert` sample records and their expected
  behaviours are used as the canonical acceptance scenarios.
