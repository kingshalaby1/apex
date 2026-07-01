# Contract: `Source` behaviour

How a domain becomes searchable. A new source type joins the system by
implementing this behaviour and registering — with **no change** to the query,
ranker or grouper (Principle VI, spec FR-017).

```elixir
@callback source_key() :: atom
@callback group_label() :: String.t()
@callback type_weight() :: number
@callback to_document(record :: term) :: Apex.Discovery.Search.Document.t()
@callback fetch_all(tenant_id :: String.t()) :: [record :: term]
```

| Callback | Purpose |
|----------|---------|
| `source_key/0` | Stable key used for selection, grouping, `Document.source` (e.g. `:invoices`). |
| `group_label/0` | Human label for the result group ("Invoices"). |
| `type_weight/0` | Fixed weight driving group order and the type layer of ranking. |
| `to_document/1` | Maps one source record to a neutral, scope-safe `Document`. The **only** place that knows the source's internal shape. |
| `fetch_all/1` | Returns all current records for a tenant — used by backfill/reindex. |

## Rules

- `to_document/1` MUST set `id` (namespaced), `source`, `tenant_id`, `title`, and
  `required_permissions`, and MUST place only **scope-safe** fields into `title`,
  `subtitle`, `metadata` and `search_terms`.
- `to_document/1` MUST set `source_version` from the record's monotonic version so
  the Indexer can apply-if-newer.
- Identifier fields that should win exact-match ranking belong in `search_terms`
  under a well-known key (e.g. `:invoice_number`, `:number`, `:unn`).

## Example (illustrative)

```elixir
defmodule Apex.Discovery.Search.Sources.Invoices do
  @behaviour Apex.Discovery.Search.Source

  @impl true
  def source_key, do: :invoices
  @impl true
  def group_label, do: "Invoices"
  @impl true
  def type_weight, do: 0.8

  @impl true
  def to_document(inv) do
    Apex.Discovery.Search.Document.new(
      id: "invoice:#{inv.id}",
      source: :invoices,
      tenant_id: inv.business_id,
      required_permissions: [:finance],
      title: inv.number,
      subtitle: inv.partner_name,
      search_terms: %{invoice_number: inv.number, trading_partner_name: inv.partner_name},
      metadata: %{status: inv.status},
      url: "/business/#{inv.business_id}/invoices/#{inv.id}",
      updated_at: inv.updated_at,
      source_version: inv.version
    )
  end

  @impl true
  def fetch_all(tenant_id), do: # ... all invoices for tenant
end
```
