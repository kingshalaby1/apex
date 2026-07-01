# Contract: Public Search API

The single public entry point for the search verb of Discovery.

```elixir
Apex.Discovery.Search.query(scope, query_text, opts \\ [])
```

## Parameters

| Param | Type | Notes |
|-------|------|-------|
| `scope` | `Scope.t()` | Required. Carries `business_id` (mandatory) + permissions. |
| `query_text` | `String.t()` | The raw phrase. Normalised internally before matching. |
| `opts` | keyword | `:limit` (overall, default 10), `:sources` (list of source keys; default all registered), `:correlation_id` (optional). |

## Returns

`Response.t()` — always. Never raises for a source failure; failures are captured
in `response.errors` with `response.degraded? == true`.

```elixir
Search.query(scope, "Gulf", limit: 10, sources: [:trading_partners, :invoices])
#=> %Response{query: "gulf", groups: [%Group{source: :trading_partners, ...}, ...],
#             degraded?: false, errors: [], meta: %{limit: 10, took_ms: 1, ...}}
```

## Semantics (invariants)

1. **Untenanted queries are impossible** — `scope.business_id` is required by
   `Scope`; there is no code path that queries without it.
2. **Tenant + permission filtering happen before results are returned** — no
   caller can receive a record outside their business or permission set.
3. **Unknown/blank query** → an empty, well-formed `Response` (no error).
4. **Unknown source in `:sources`** → treated per the fail-safe policy (recorded in
   `errors`, not a crash).
5. **Deterministic ordering** — groups in fixed source priority; results within a
   group by the layered ranking key.
6. **Bounded** — per-group cap 5, overall limit 10 unless overridden.

## Example result element

```elixir
%Result{
  source: :invoices,
  id: "invoice:inv_123",
  title: "INV-123",
  subtitle: "Gulf Trading",
  url: "/business/acme/invoices/inv_123",
  score: 0.98,
  matched_fields: [:invoice_number],
  metadata: %{status: :overdue}
}
```
