defmodule Apex.Remittance.PaymentRequest.Store do
  @moduledoc false
  # Stateful in-memory stand-in for the Remittance datastore — the "table" of
  # payment requests, held as `%{id => PaymentRequest}` in an Agent so it supports
  # writes. Swap this for a real Repo when persistence is introduced; the context
  # (Apex.Remittance) is the only caller.

  use Agent

  alias Apex.Remittance.PaymentRequest

  @seed [
    %PaymentRequest{
      id: "pr_111",
      business_id: "acme",
      number: "111",
      payer_name: "Gulf LLC",
      state: :active,
      version: 1,
      updated_at: ~U[2026-06-05 09:00:00Z]
    },
    %PaymentRequest{
      id: "pr_222",
      business_id: "acme",
      number: "222",
      payer_name: "Gulf Trading",
      state: :expired,
      version: 1,
      updated_at: ~U[2026-06-12 09:00:00Z]
    }
  ]

  def start_link(_opts) do
    Agent.start_link(fn -> Map.new(@seed, &{&1.id, &1}) end, name: __MODULE__)
  end

  @spec all() :: [PaymentRequest.t()]
  def all, do: Agent.get(__MODULE__, &Map.values/1)

  @spec get(String.t()) :: PaymentRequest.t() | nil
  def get(id), do: Agent.get(__MODULE__, &Map.get(&1, id))

  @spec put(PaymentRequest.t()) :: :ok
  def put(%PaymentRequest{} = pr), do: Agent.update(__MODULE__, &Map.put(&1, pr.id, pr))

  @spec delete(String.t()) :: :ok
  def delete(id), do: Agent.update(__MODULE__, &Map.delete(&1, id))
end
