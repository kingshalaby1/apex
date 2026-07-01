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

  @doc "Public read API: trading partners for a business (tenant)."
  @spec list_trading_partners(String.t()) :: [TradingPartner.t()]
  def list_trading_partners(business_id) do
    TradingPartner.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end
end
