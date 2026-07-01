# Phase 1 Data Model: Global Search

The neutral shapes the pipeline flows through. The core structs already exist in
`lib/apex/discovery/search/`; this document is the authoritative description of
their fields, relationships and rules, plus how the sample data maps onto them.

## Entities

### Scope — caller authorisation context

| Field | Type | Rules |
|-------|------|-------|
| `business_id` | string | **Required.** Tenant key. A query MUST NOT run without it. |
| `actor_id` | string \| nil | User id, for audit. |
| `permissions` | MapSet(atom) | Coarse grants, e.g. `:finance`, `:payments`. |
| `locale` | string | `"en"` / `"ar"`; affects normalisation/display, not authz. |

Derived server-side from the authenticated session; never from client query input.
Helper: `Scope.permits?(scope, required)` → all of `required` ⊆ `permissions`.

### Document — neutral indexed record (the projection unit)

| Field | Type | Rules |
|-------|------|-------|
| `id` | string | **Required.** Namespaced, globally unique: `"invoice:inv_123"`. Idempotent upsert key. |
| `source` | atom | **Required.** Source key, e.g. `:invoices`. |
| `tenant_id` | string | **Required.** Owning business. First-class field; tenant filter uses it. |
| `title` | string | **Required.** Scope-safe display title. |
| `subtitle` | string \| nil | Scope-safe secondary line. |
| `required_permissions` | [atom] | Permissions needed to view; `[]` = ungated. |
| `search_terms` | %{atom => string} | Field → searchable text; drives `matched_fields` + exact-id. |
| `metadata` | map | Scope-safe extra fields (e.g. `%{status: :overdue}`). |
| `url` | string \| nil | Deep link into the owning context. |
| `updated_at` | DateTime \| nil | Recency signal for ranking. |
| `source_version` | non_neg_integer | Monotonic; enables apply-if-newer idempotency. |
| `indexed_at` | DateTime | Stamped at index time; exposes index lag. |

Rule: a `Document` contains **only** fields safe for anyone permitted to see the
record. Nothing sensitive is stored "for later filtering".

### Result — scope-safe output

`source`, `id`, `title`, `subtitle`, `url`, `score` (float), `matched_fields`
([atom]), `metadata`. Produced by projecting a permitted `Document` + its score.

### Group — results for one source

`source` (atom), `label` (string, e.g. "Invoices"), `results` ([Result]). Bounded
by the per-group cap; ordered within by score.

### Response — the full query outcome

`query` (normalised string), `groups` ([Group], fixed source order), `degraded?`
(bool), `errors` ([%{source, reason}]), `meta` (map: `limit`, `took_ms`,
`sources`, `correlation_id`).

### Source (Object Type) — a searchable domain

Not a struct — a **module** implementing the `Source` behaviour (see
`contracts/source.md`). Declares `source_key`, `group_label`, `type_weight`,
`to_document/1`, `fetch_all/1`. v1: trading partners, invoices, payment requests.

## Relationships

```text
Scope ──authorises──▶ Query ──selects──▶ Source(s)
                                   │
Source.to_document/1 ─────────────▶ Document ──stored in──▶ Index
                                                   │
Query ─▶ Index.query ─▶ [Document] ─▶ Authorizer ─▶ Ranker ─▶ Grouper ─▶ Response
                                          │
                                   (tenant + permission)
```

## Sample data → Documents

| Source | id | tenant_id | required_permissions | title | subtitle | search_terms (normalised) | metadata |
|--------|----|-----------|----------------------|-------|----------|---------------------------|----------|
| trading_partners | `trading_partner:tp_1` | acme | `[]` | Gulf Trading | UNN 7000000001 | name:"gulf trading", unn:"7000000001" | verified: true |
| trading_partners | `trading_partner:tp_2` | acme | `[]` | Gulf LLC | UNN 7000000002 | name:"gulf llc", unn:"7000000002" | verified: false |
| trading_partners | `trading_partner:tp_3` | desert | `[]` | Gulf Trading | UNN 7000000001 | name:"gulf trading", unn:"7000000001" | verified: true |
| invoices | `invoice:inv_123` | acme | `[:finance]` | INV-123 | Gulf Trading | invoice_number:"inv-123", partner:"gulf trading" | status: overdue |
| invoices | `invoice:inv_222` | acme | `[:finance]` | INV-222 | Gulf Trading | invoice_number:"inv-222", partner:"gulf trading" | status: paid |
| invoices | `invoice:inv_999` | desert | `[:finance]` | INV-999 | Gulf Trading | invoice_number:"inv-999", partner:"gulf trading" | status: overdue |
| payment_requests | `payment_request:pr_111` | acme | `[:payments]` | 111 | Gulf LLC | number:"111", payer:"gulf llc" | state: active |
| payment_requests | `payment_request:pr_222` | acme | `[:payments]` | 222 | Gulf Trading | number:"222", payer:"gulf trading" | state: expired |

Trading partners carry `required_permissions: []` (visible to all users of the
business); invoices require `:finance`; payment requests require `:payments`.
Tenant isolation is by `tenant_id`; the `desert` rows never appear for `acme`.
