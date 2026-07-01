defmodule Apex.Discovery.Search.Group do
  @moduledoc """
  A group of results for a single source, e.g. "Trading Partners" or "Invoices".

  Grouping is what makes the result list scannable: results are bucketed by
  `source`, labelled with the source's human name, and truncated to a per-group
  limit. Groups are ordered by the design's grouping policy (see the ranker).
  """

  @enforce_keys [:source, :label, :results]
  defstruct source: nil, label: nil, results: []

  @type t :: %__MODULE__{
          source: atom(),
          label: String.t(),
          results: [Apex.Discovery.Search.Result.t()]
        }
end
