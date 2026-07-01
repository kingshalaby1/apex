defmodule Apex.Discovery do
  @moduledoc """
  Discovery context — **owns derived read-side search and discovery projections**.

  Discovery does not own any canonical business data. It maintains a **derived,
  rebuildable read model** (the search index) built by subscribing to domain
  events from the source contexts (Account, Billing, Remittance, …). It answers
  scoped queries over that read model.

  Search is a **behaviour (verb)** of Discovery, alongside future verbs such as
  browse/discover and suggest/autocomplete over the same projections.

  ## Boundary

    * Discovery reads **only its own projection** — never another context's
      internal tables, and never the Ledger.
    * The projection is **not a source of truth**; it can be rebuilt from source
      at any time via backfill.
    * Results are always scoped: tenant isolation and permission filtering are
      enforced before any result is returned.

  ## Public entry point

  `Apex.Discovery.Search.query/3` (added in a later step) is the public search
  API:

      Apex.Discovery.Search.query(scope, "Gulf", limit: 10, sources: [:trading_partners, :invoices])
  """

  # Public API — added in a later step.
end
