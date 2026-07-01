defmodule Apex.Account do
  @moduledoc """
  Account context — **owns business identity and trading-partner relationships**.

  Canonical records:

    * Business identity — the canonical business record, verification state and
      published profile.
    * Trading-partner relationships — relationship-scoped counterparty records
      and contact data.

  ## Boundary

  Account is the source of truth for these records. Other contexts must not read
  Account's internal tables. Account collaborates by:

    * exposing a public API for reads/writes it chooses to publish, and
    * emitting domain events (e.g. `TradingPartnerAdded`, `TradingPartnerUpdated`)
      that derived consumers — such as the Discovery search index — subscribe to.

  ## Search participation

  Account provides a search *source adapter* (see `Apex.Discovery.Source`) that
  maps a trading-partner record into a neutral search document. Trading partners
  are one of the version-one searchable sources.
  """

  # Public API — added in a later step.
end
