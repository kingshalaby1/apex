defmodule Apex.Account.TradingPartner.Store do
  @moduledoc false
  # Stateful in-memory stand-in for the Account datastore — the "table" of trading
  # partners, held as `%{id => TradingPartner}` in an Agent so it supports writes.
  # Swap this for a real Repo when persistence is introduced; the context
  # (Apex.Account) is the only caller.

  use Agent

  alias Apex.Account.TradingPartner

  @seed [
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

  def start_link(_opts) do
    Agent.start_link(fn -> Map.new(@seed, &{&1.id, &1}) end, name: __MODULE__)
  end

  @spec all() :: [TradingPartner.t()]
  def all, do: Agent.get(__MODULE__, &Map.values/1)

  @spec get(String.t()) :: TradingPartner.t() | nil
  def get(id), do: Agent.get(__MODULE__, &Map.get(&1, id))

  @spec put(TradingPartner.t()) :: :ok
  def put(%TradingPartner{} = tp), do: Agent.update(__MODULE__, &Map.put(&1, tp.id, tp))

  @spec delete(String.t()) :: :ok
  def delete(id), do: Agent.update(__MODULE__, &Map.delete(&1, id))
end
