defmodule Apex.Discovery.Search.Document do
  @moduledoc """
  A **neutral searchable record** — the unit stored in the Discovery search index.

  Every searchable source maps its own records into this one shape (via its
  `Apex.Discovery.Source` adapter), so the index, ranker and query pipeline never
  need to know about invoices, trading partners or payment requests specifically.

  ## Fields and their role

    * `id` — globally unique, **namespaced** identifier (`"invoice:inv_123"`).
      Serves as the idempotent upsert key so backfill and live events converge on
      the same row instead of duplicating it.
    * `source` — the source key (e.g. `:invoices`) used for grouping and filtering.
    * `tenant_id` — the owning business. A **first-class field, never buried in
      metadata**, so the tenant filter is cheap and unavoidable.
    * `required_permissions` — the permissions a scope must hold to see this
      result (e.g. `[:finance]`). Drives redaction/omission at query time.
    * `title` / `subtitle` — the human-facing snippet. Only scope-safe text.
    * `search_terms` — `field => searchable_text`. Keyed by field so the ranker can
      report `matched_fields` and boost exact-identifier matches over loose ones.
    * `metadata` — extra **scope-safe** fields surfaced to the UI (e.g.
      `%{status: :overdue}`). The source decides what is safe to expose.
    * `url` — deep link to the record in its owning context.
    * `updated_at` — recency signal for ranking (source's last-changed time).
    * `source_version` — monotonic version/sequence from the source. Enables
      **apply-if-newer** idempotency: a late write cannot clobber a fresher one.
    * `indexed_at` — when Discovery wrote this document (observability / index lag).

  The document is a **projection, not a source of truth** — it can be rebuilt from
  the source at any time.
  """

  @enforce_keys [:id, :source, :tenant_id, :title]
  defstruct [
    :id,
    :source,
    :tenant_id,
    :title,
    :subtitle,
    :url,
    :updated_at,
    required_permissions: [],
    search_terms: %{},
    metadata: %{},
    source_version: 0,
    indexed_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          source: atom(),
          tenant_id: String.t(),
          title: String.t(),
          subtitle: String.t() | nil,
          url: String.t() | nil,
          updated_at: DateTime.t() | nil,
          required_permissions: [atom()],
          search_terms: %{optional(atom()) => String.t()},
          metadata: map(),
          source_version: non_neg_integer(),
          indexed_at: DateTime.t() | nil
        }

  @doc """
  Builds a `Document`. Requires `:id`, `:source`, `:tenant_id` and `:title`
  (raises otherwise) and stamps `:indexed_at` if not supplied.
  """
  @spec new(Enumerable.t()) :: t()
  def new(attrs) do
    __MODULE__
    |> struct!(Map.new(attrs))
    |> stamp_indexed_at()
  end

  defp stamp_indexed_at(%__MODULE__{indexed_at: nil} = doc),
    do: %{doc | indexed_at: DateTime.utc_now()}

  defp stamp_indexed_at(%__MODULE__{} = doc), do: doc
end
