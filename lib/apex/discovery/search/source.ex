defmodule Apex.Discovery.Search.Source do
  @moduledoc """
  The contract a domain implements to become searchable.

  A new searchable object type joins global search by implementing this behaviour
  and registering it (see `Apex.Discovery.Search.Registry`) — with **no change** to
  the query, ranking or grouping pipeline (constitution Principle VI, spec FR-017).

  The adapter is the only code that understands both the owning context's record
  shape and the neutral `Apex.Discovery.Search.Document`. It MUST place only
  scope-safe fields into the document and declare the permissions required to view
  a result.
  """

  alias Apex.Discovery.Search.Document

  @doc "Stable key for selection, grouping and `Document.source` (e.g. `:invoices`)."
  @callback source_key() :: atom()

  @doc "Human label for the result group (e.g. \"Invoices\")."
  @callback group_label() :: String.t()

  @doc "Fixed weight driving group order and the type layer of ranking (higher = earlier)."
  @callback type_weight() :: number()

  @doc "Maps one owning-context record to a neutral, scope-safe document."
  @callback to_document(record :: term()) :: Document.t()

  @doc "Returns all current records for a tenant — used by backfill/reindex."
  @callback fetch_all(tenant_id :: String.t()) :: [record :: term()]
end
