<!--
Sync Impact Report
==================
Version change: (unversioned template) → 1.0.0
Bump rationale: First ratification of the project constitution (initial adoption
of all principles and governance).

Principles defined (I–VI):
  I.   Bounded Contexts Own Their Data — Public APIs Only
  II.  Search Is a Read Model, Never a Source of Truth
  III. Cross-Context Data Is Eventually Consistent and Stale-Aware
  IV.  Tenant Isolation and Authorisation Before Results
  V.   Least-Disclosure Snippets
  VI.  Explicit, Reusable, Decoupled Contracts

Added sections:
  - Operational & Quality Constraints
  - Development Workflow & Quality Gates
  - Governance

Removed sections: none (template placeholders replaced).

Templates reviewed for consistency:
  ✅ .specify/templates/plan-template.md      — generic "Constitution Check" gate
        reads this file at plan time; no change required.
  ✅ .specify/templates/spec-template.md       — no constitution coupling; no change.
  ✅ .specify/templates/tasks-template.md       — no constitution coupling; no change.
  ✅ .specify/templates/checklist-template.md   — no constitution coupling; no change.

Deferred TODOs: none. RATIFICATION_DATE set to first adoption date (2026-07-01).
-->

# Apex Global Search Constitution

Apex is a domain-oriented B2B trade and financing platform. Global search is a
**behaviour of the Discovery context**: it reads a derived projection and returns
grouped, tenant-safe results across business objects (trading partners, invoices,
payment requests, and future sources). This constitution defines the
non-negotiable rules that every specification, plan, task, and change to global
search MUST satisfy.

## Core Principles

### I. Bounded Contexts Own Their Data — Public APIs Only

Every bounded context (Account, Billing, Remittance, Ledger, …) owns its data and
invariants. Search MUST NOT read another context's internal tables, database, or
private state. It consumes searchable data **only** through published public APIs
and domain events. New data enters the index by a source context emitting events
or exposing an explicit read contract — never by search reaching in.

**Rationale:** Preserves domain boundaries and keeps every context independently
evolvable and extractable; a shared search layer must not become hidden coupling.

### II. Search Is a Read Model, Never a Source of Truth

The owning context decides canonical state and is strongly consistent within its
boundary. The search index is a **derived, rebuildable projection**. It MUST NOT
be treated as authoritative: no balance, status, or decision may be taken from the
index in place of the owning context. The index MUST be reconstructable from
source at any time (backfill/reindex) and MUST be safe to discard and rebuild.

**Rationale:** Correctness. A stale copy standing in for truth — especially for
financial state — is the most damaging failure mode search can have.

### III. Cross-Context Data Is Eventually Consistent and Stale-Aware

Results are projection-based and MAY be slightly stale. The system MUST tolerate
staleness rather than assume freshness: indexing is asynchronous, apply-if-newer
and idempotent, and MUST support backfill to repair gaps. Index lag MUST be
observable, and the design MUST NOT present the projection as real-time truth.

**Rationale:** Honesty to the domain. Cross-context consistency is eventual;
pretending otherwise produces silent, hard-to-diagnose errors.

### IV. Tenant Isolation and Authorisation Before Results

Every query executes within a `Scope` carrying a mandatory tenant key
(`business_id`) and the caller's permissions. A query MUST NEVER run untenanted.
Tenant filtering and permission checks MUST be applied **before** any result
leaves the system — never as a client-side or post-hoc concern. A caller MUST see
only records they are authorised to see.

**Rationale:** Security. Tenant isolation is mandatory; leaking another business's
records is a critical failure, so isolation is enforced at the core, not the edge.

### V. Least-Disclosure Snippets

A search document carries only **scope-safe** fields. Each document MUST declare
the permissions required to view it; results the caller is not permitted to see
MUST be omitted or safely redacted. Snippets (title, subtitle, metadata) MUST NOT
expose private, internal-only, or sensitive financial detail. When in doubt, a
field is excluded from the index rather than filtered at query time.

**Rationale:** Privacy. Financial records are sensitive; the index should never
hold, and results should never surface, more than the current scope may see.

### VI. Explicit, Reusable, Decoupled Contracts

Searchable sources join through **one explicit contract** (a `Source` behaviour),
and storage/retrieval is reached through **one swappable contract** (an `Index`
behaviour). Adding a new searchable source MUST NOT require changing the query
pipeline, ranker, or grouping logic. Contracts MUST be explicit and avoid
accidental coupling so that any context can later be extracted without unwinding
search.

**Rationale:** Reusability and evolvability. Future result types and future
storage engines (Postgres FTS, external search, hybrid/AI retrieval) must slot in
behind stable contracts, not by rewriting the system.

## Operational & Quality Constraints

- **Fail safe, not all-or-nothing.** A failing or missing source MUST degrade the
  response (recorded per-source error + `degraded?` flag) while healthy sources
  still return results. A single source failure MUST NOT fail the whole query.
- **Predictable query latency.** The query path reads only the projection. It MUST
  NOT perform large cross-domain joins or fan out to source contexts at query time.
- **Observability.** Queries carry a correlation id. Index lag, failed indexing
  jobs, and stale projections MUST be detectable. Sensitive searches and result
  clicks SHOULD be auditable where appropriate.
- **Internationalisation.** The design MUST acknowledge Arabic and English names:
  text normalisation (case and diacritics folding) is applied consistently to
  indexed terms and queries, and right-to-left content is not corrupted.
- **Data minimisation.** The index stores only what search needs: identifiers,
  the tenant key, `required_permissions`, normalised search terms, and scope-safe
  snippet/metadata fields.

## Development Workflow & Quality Gates

- **Spec-driven.** Work flows through the Spec Kit stages: constitution → specify →
  plan → tasks → implement. Each stage MUST remain consistent with this document.
- **Constitution Check.** Every plan MUST include a Constitution Check; any
  violation MUST be justified in the plan's Complexity Tracking or the approach
  changed to comply.
- **Boundary & invariant tests are mandatory.** At minimum, the suite MUST cover:
  tenant isolation, permission redaction/omission, exact-identifier ranking
  precedence, and idempotent (apply-if-newer) upserts.
- **Modest by design.** Prefer clarity and defensible boundaries over feature
  breadth. Deliberately deferred scope MUST be documented as a non-goal, not left
  implicit.

## Governance

This constitution supersedes ad-hoc practice for global search. When guidance
conflicts, the constitution wins.

- **Amendments** MUST be documented in this file, dated, and versioned. Each
  amendment updates the Sync Impact Report and propagates to dependent templates.
- **Versioning** follows semantic versioning: **MAJOR** for backward-incompatible
  principle removals or redefinitions, **MINOR** for a new principle or materially
  expanded section, **PATCH** for clarifications and non-semantic wording.
- **Compliance.** Specs, plans, and reviews MUST verify compliance with these
  principles. Added complexity MUST be justified against the principle it
  pressures; unjustified violations block the change.

**Version**: 1.0.0 | **Ratified**: 2026-07-01 | **Last Amended**: 2026-07-01
