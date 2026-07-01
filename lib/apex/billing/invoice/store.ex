defmodule Apex.Billing.Invoice.Store do
  @moduledoc false
  # In-memory stand-in for the Billing datastore — the "table" of invoices.
  # Swap `all/0` for a real Repo query when persistence is introduced; the context
  # (Apex.Billing) is the only caller.

  alias Apex.Billing.Invoice

  @records [
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

  @spec all() :: [Invoice.t()]
  def all, do: @records
end
