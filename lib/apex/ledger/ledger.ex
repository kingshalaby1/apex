defmodule Apex.Ledger do
  @moduledoc """
  Ledger context — **owns append-only accounting entries**.

  The Ledger records the *financial meaning* of posted events using a double-entry,
  append-only accounting model. It is the **financial source of truth**: balances,
  reconciliation, reporting and audit derive from it. Entries are never edited in
  place; corrections are posted as reversing entries.

  ## Boundary

  Ledger is the source of truth for accounting entries. Like the source contexts,
  it *subscribes* to domain events that carry accounting meaning (e.g.
  `PaymentReceived`, `FeeCharged`) and posts its own entries — but it does so for
  **accounting**, not for search.

  ## Search participation — deferred (non-goal for version one)

  Ledger is intentionally **not** a version-one search source:

    * It holds no human-searchable name — entries reference other objects by id.
    * It is the highest-sensitivity financial data with the lowest search payoff.
    * Making a stale search projection stand in for the ledger would violate the
      rule that *search must not become a second source of truth*.

  If ledger search is ever justified, it re-enters either as an **enrichment
  signal** on other results (e.g. an invoice's outstanding balance) or as a
  **narrow exact-reference lookup**, by implementing `Apex.Discovery.Source` with
  no change to the search pipeline.
  """

  # Public API — added in a later step.
end
