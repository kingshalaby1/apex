# Apex Global Search

A reusable global search capability for **Apex**, a domain-oriented B2B trade and
financing platform. Type a phrase (e.g. `Gulf`) and get **grouped, tenant-safe**
results across trading partners, invoices and payment requests — with more object
types able to join without reworking the pipeline.

This repository is a deliberately small Elixir skeleton that proves the design.
The design itself is in **[ARCHITECTURE.md](ARCHITECTURE.md)**; trade-offs and
rejected alternatives in **[DECISIONS.md](DECISIONS.md)**; the governing principles
in [`.specify/memory/constitution.md`](.specify/memory/constitution.md); and the
full spec/plan in [`specs/001-global-search/`](specs/001-global-search/).

## Design in one minute

- **Search is a behaviour of the Discovery context**, not a context of its own.
- Source contexts emit events; Discovery projects them into a **derived,
  rebuildable index** and queries only that index — never another context's tables,
  never the Ledger.
- A query flows: **normalise → resolve sources → retrieve (per source, isolated) →
  authorise (tenant + permissions) → rank (exact-id first) → group (fixed order,
  bounded)**.
- Reusability via two contracts: a **`Source`** behaviour (how a domain joins) and
  a swappable **`Index`** behaviour (in-memory now, Postgres/OpenSearch later).

## Requirements

- Elixir **1.18.3** / Erlang **OTP 26** (pinned in [`.tool-versions`](.tool-versions)).
- No external dependencies, database or search engine.

## Run

```bash
mix deps.get     # no-op — there are no dependencies
mix compile
mix test         # 33 boundary/invariant + end-to-end tests
```

## Try it

```bash
iex -S mix
```

```elixir
alias Apex.Discovery.Search
alias Apex.Discovery.Search.Scope

# An acme user with finance + payments permission (sample data is seeded at startup)
scope = Scope.new(business_id: "acme", actor_id: "user_42", permissions: [:finance, :payments])

Search.query(scope, "Gulf", limit: 10)
#=> %Response{groups: [%Group{label: "Trading Partners", ...}, %Group{label: "Invoices", ...}, ...]}

# Exact identifier wins
Search.query(scope, "INV-123")            # INV-123 is the top result

# Restrict to specific object types
Search.query(scope, "Gulf", sources: [:trading_partners])

# Permissions gate results (no :finance → no invoices)
Search.query(Scope.new(business_id: "acme", permissions: [:payments]), "INV-123")
```

### Live indexing (write → event → searchable)

A context write publishes a domain event on `Apex.EventBus`; the search
`EventSubscriber` projects it into the index — the context never calls search.

```elixir
Apex.Billing.create_invoice(%{id: "inv_9", business_id: "acme",
  number: "INV-9", partner_name: "Zephyr Trading", status: :draft})

Search.query(scope, "Zephyr")   # the new invoice is now searchable (eventually)
```

## What the tests prove

| Behaviour | Where |
|-----------|-------|
| Tenant isolation (no cross-business leakage) | `search_test.exs`, `authorizer_test.exs` |
| Permission redaction (omit-on-deny) | `search_test.exs`, `authorizer_test.exs` |
| Exact-identifier ranking + recency tiebreak | `ranker_test.exs` |
| Idempotent, apply-if-newer indexing + backfill | `index_in_memory_test.exs`, `indexer_test.exs` |
| Live write → event → searchable (create/update/delete) | `event_flow_test.exs` |
| Fail-safe partial results (degraded, not crashed) | `search_test.exs` |
| Arabic/English normalisation | `normalizer_test.exs` |

## Layout

Each context module is a file next to its own directory (Elixir/Phoenix
convention): the module is the public front door, its models live in the folder.

```
lib/apex/
  account.ex                          # Apex.Account — public read API (list_trading_partners/1)
  account/trading_partner.ex          # Apex.Account.TradingPartner (pure struct / model)
  account/trading_partner/store.ex    # datastore stand-in (sample rows; a Repo later)
  billing.ex                          # Apex.Billing — list_invoices/1
  billing/invoice.ex                  # Apex.Billing.Invoice
  billing/invoice/store.ex            # datastore stand-in
  remittance.ex                       # Apex.Remittance — list_payment_requests/1
  remittance/payment_request.ex       # Apex.Remittance.PaymentRequest
  remittance/payment_request/store.ex # datastore stand-in
  ledger.ex                           # Apex.Ledger — search-deferred (non-goal)
  discovery.ex                        # Apex.Discovery — owns search
  discovery/search/
    search.ex              # public API: query/3
    scope.ex document.ex result.ex group.ex response.ex   # neutral shapes
    source.ex index.ex     # reusability contracts (behaviours)
    index/in_memory.ex     # swappable in-memory index adapter
    registry.ex indexer.ex normalizer.ex                  # projection + i18n
    authorizer.ex ranker.ex grouper.ex telemetry.ex       # query pipeline
    sources/               # adapters: map a context model -> Document, fetch_all -> context API
specs/001-global-search/   # spec, plan, research, data-model, contracts, quickstart, tasks
```

Each **source context owns its data and a public read API** (`list_*`); the
search **adapters** under `discovery/search/sources/` only *map* a context's model
into a `Document` and delegate `fetch_all` to that context — they hold no data of
their own.

## Scope

**In v1:** trading partners, invoices, payment requests; tenant + coarse
(role-style) permissions; deterministic ranking and grouping; fail-safe partials.

**Deferred (documented non-goals):** Ledger as a search source, per-record ACLs,
autocomplete, ML ranking, cross-business discovery, and an external search engine —
each admitted later behind the existing contracts. See
[DECISIONS.md](DECISIONS.md).
