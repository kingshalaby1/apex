defmodule Apex.Account.TradingPartner.Store do
  @moduledoc false
  # In-memory stand-in for the Account datastore — the "table" of trading
  # partners. Swap `all/0` for a real Repo query when persistence is introduced;
  # the context (Apex.Account) is the only caller.

  alias Apex.Account.TradingPartner

  @records [
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

  @spec all() :: [TradingPartner.t()]
  def all, do: @records
end
