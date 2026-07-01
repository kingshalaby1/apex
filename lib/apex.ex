defmodule Apex do
  @moduledoc """
  Apex is a B2B trade and financing enablement platform.

  The system is organised into **bounded contexts**. Each context owns its own
  data, invariants and public API. Cross-context access to another context's
  internal tables is not allowed — contexts collaborate through public functions
  and domain events only.

  ## Contexts

    * `Apex.Account`     — business identity and trading-partner relationships
    * `Apex.Billing`     — invoices (legal commercial documents)
    * `Apex.Remittance`  — payment obligations, payment links, payment requests
    * `Apex.Ledger`      — append-only accounting entries (financial source of truth)
    * `Apex.Discovery`   — derived read-side search and discovery projections

  ## Global search

  Search is a **behaviour of `Apex.Discovery`**, not a context of its own.
  Discovery maintains a derived, rebuildable search index fed by domain events
  from the source contexts, and answers scoped queries over that index. Search
  never reads another context's internal tables and is never a source of truth.
  """
end
