# Quickstart: Global Search

How to run the skeleton and validate that the design works end-to-end. No
database, Phoenix or external search engine is required.

## Prerequisites

- Elixir 1.18.3 / Erlang OTP 26 (pinned in `.tool-versions`).
- No external dependencies to fetch (`mix deps.get` is a no-op for v1).

## Run

```bash
mix deps.get      # no-op (no deps yet)
mix compile
mix test          # runs the boundary/invariant suite
```

## Try it in IEx

Once the pipeline and sample sources are implemented (Phase 2), the sample data is
seeded into the in-memory index at start (or via a `seed/0` helper), and:

```elixir
iex -S mix

# An acme user with finance + payments permission
scope = Apex.Discovery.Search.Scope.new(
  business_id: "acme",
  actor_id: "user_42",
  permissions: [:finance, :payments]
)

Apex.Discovery.Search.query(scope, "Gulf", limit: 10)
```

## Validation scenarios (from the sample data)

Each maps to an acceptance scenario in [spec.md](spec.md) and a test in
`test/apex/discovery/search/`.

| # | Scope / query | Expected outcome |
|---|---------------|------------------|
| 1 | acme (finance+payments) searches "Gulf" | Groups for Trading Partners (Gulf Trading, Gulf LLC), Invoices (INV-123, INV-222), Payment Requests (111, 222). No `desert` rows. |
| 2 | desert user searches "Gulf" | Only `desert`-visible results; never acme's invoices/payment requests. |
| 3 | acme user **without** `:finance` searches "INV-123" | Invoice omitted entirely (no stub). |
| 4 | acme user **without** `:payments` searches "Gulf" | No Payment Request group. |
| 5 | acme finance user searches "INV-123" | INV-123 is the **top** result, above trading-partner "Gulf" matches. |
| 6 | acme searches "Gulf" with `sources: [:trading_partners]` | Only Trading Partner results. |
| 7 | Payment Requests source made to fail, acme searches "Gulf" | Trading Partner + Invoice groups still returned; `degraded? == true`, `errors` names `:payment_requests`. |

## What "done" looks like

- `mix test` green, covering: tenant isolation (1, 2), permission redaction (3, 4),
  exact-id ranking precedence (5), source filtering (6), fail-safe partial results
  (7), and idempotent apply-if-newer indexing.
- `Search.query/3` returns a well-formed `Response` for every scenario, including
  empty and degraded cases.

Full module and test bodies are produced during `/speckit-tasks` +
`/speckit-implement`; this guide only defines how to run and what to expect.
