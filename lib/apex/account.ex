defmodule Apex.Account do
  @moduledoc """
  Account context — **owns business identity and trading-partner relationships**.

  Canonical records:

    * Business identity — the canonical business record, verification state and
      published profile.
    * Trading-partner relationships — relationship-scoped counterparty records
      and contact data (`Apex.Account.TradingPartner`).

  ## Boundary

  Account is the source of truth for these records. Other contexts must not read
  Account's internal tables; they use this **public API** (and, in a real system,
  Account's domain events). `list_trading_partners/1` is the read the search
  projection consumes for backfill.
  """

  alias Apex.Account.TradingPartner

  # Stand-in for Account's store. In production this is backed by the context's
  # database; here it is in-process sample data.
  @trading_partners [
    %TradingPartner{
      id: "tp_1",
      business_id: "acme",
      name: "Gulf Trading",
      unn: "7000000001",
      verified: true,
      version: 1,
      updated_at: ~U[2026-06-01 09:00:00Z]
    },
    %TradingPartner{
      id: "tp_2",
      business_id: "acme",
      name: "Gulf LLC",
      unn: "7000000002",
      verified: false,
      version: 1,
      updated_at: ~U[2026-06-02 09:00:00Z]
    },
    %TradingPartner{
      id: "tp_3",
      business_id: "desert",
      name: "Gulf Trading",
      unn: "7000000001",
      verified: true,
      version: 1,
      updated_at: ~U[2026-06-01 09:00:00Z]
    }
  ]

  @doc "Public read API: trading partners for a business (tenant)."
  @spec list_trading_partners(String.t()) :: [TradingPartner.t()]
  def list_trading_partners(business_id) do
    Enum.filter(@trading_partners, &(&1.business_id == business_id))
  end
end
