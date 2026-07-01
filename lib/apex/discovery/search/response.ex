defmodule Apex.Discovery.Search.Response do
  @moduledoc """
  The full result of a query: grouped results plus fail-safe metadata.

  Search **fails partially, not totally**. If one source errors or times out, its
  failure is recorded in `errors` and `degraded` is set to `true`, while every
  healthy source still returns its group. Callers can render available results and
  signal that the view is incomplete rather than showing nothing.

  ## Fields

    * `query` — the (normalised) query text.
    * `groups` — the surviving result groups, in display order.
    * `degraded?` — `true` when at least one selected source failed.
    * `errors` — per-source failures as `%{source: atom, reason: term}`.
    * `meta` — operational context (e.g. `limit`, `took_ms`, selected `sources`).
  """

  @enforce_keys [:query]
  defstruct query: nil,
            groups: [],
            degraded?: false,
            errors: [],
            meta: %{}

  @type source_error :: %{source: atom(), reason: term()}

  @type t :: %__MODULE__{
          query: String.t(),
          groups: [Apex.Discovery.Search.Group.t()],
          degraded?: boolean(),
          errors: [source_error()],
          meta: map()
        }
end
