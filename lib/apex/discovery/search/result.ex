defmodule Apex.Discovery.Search.Result do
  @moduledoc """
  A single, scope-safe search result returned to the caller.

  This is the **output** shape (the projection is `Apex.Discovery.Search.Document`).
  It carries only what the current scope is allowed to see: the snippet fields,
  a deep link, the computed `score`, and the `matched_fields` that explain the hit.
  """

  @enforce_keys [:source, :id, :title, :score]
  defstruct [
    :source,
    :id,
    :title,
    :subtitle,
    :url,
    :score,
    matched_fields: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          source: atom(),
          id: String.t(),
          title: String.t(),
          subtitle: String.t() | nil,
          url: String.t() | nil,
          score: float(),
          matched_fields: [atom()],
          metadata: map()
        }
end
