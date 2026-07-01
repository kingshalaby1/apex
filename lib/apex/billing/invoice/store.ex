defmodule Apex.Billing.Invoice.Store do
  @moduledoc false
  # Stateful in-memory stand-in for the Billing datastore — the "table" of
  # invoices, held as `%{id => Invoice}` in an Agent so it supports writes.
  # Swap this for a real Repo when persistence is introduced; the context
  # (Apex.Billing) is the only caller.

  use Agent

  alias Apex.Billing.Invoice

  @seed [
    %Invoice{
      id: "inv_123",
      business_id: "acme",
      number: "INV-123",
      partner_name: "Gulf Trading",
      status: :overdue,
      version: 1,
      updated_at: ~U[2026-06-10 09:00:00Z]
    },
    %Invoice{
      id: "inv_222",
      business_id: "acme",
      number: "INV-222",
      partner_name: "Gulf Trading",
      status: :paid,
      version: 1,
      updated_at: ~U[2026-06-20 09:00:00Z]
    },
    %Invoice{
      id: "inv_999",
      business_id: "desert",
      number: "INV-999",
      partner_name: "Gulf Trading",
      status: :overdue,
      version: 1,
      updated_at: ~U[2026-06-15 09:00:00Z]
    }
  ]

  def start_link(_opts) do
    Agent.start_link(fn -> Map.new(@seed, &{&1.id, &1}) end, name: __MODULE__)
  end

  @spec all() :: [Invoice.t()]
  def all, do: Agent.get(__MODULE__, &Map.values/1)

  @spec get(String.t()) :: Invoice.t() | nil
  def get(id), do: Agent.get(__MODULE__, &Map.get(&1, id))

  @spec put(Invoice.t()) :: :ok
  def put(%Invoice{} = invoice), do: Agent.update(__MODULE__, &Map.put(&1, invoice.id, invoice))

  @spec delete(String.t()) :: :ok
  def delete(id), do: Agent.update(__MODULE__, &Map.delete(&1, id))
end
