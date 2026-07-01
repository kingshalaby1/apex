defmodule Apex.Billing do
  @moduledoc """
  Billing context — **owns invoices**.

  Invoices are legal commercial documents carrying payment-status signals
  (e.g. `:overdue`, `:paid`). Billing decides the canonical state of an invoice
  (`Apex.Billing.Invoice`).

  ## Boundary

  Billing is the source of truth for invoices. Other contexts must not read
  Billing's internal tables; they use this **public API** (and, in a real system,
  Billing's domain events such as `InvoiceCreated` / `InvoicePaid`).
  `list_invoices/1` is the read the search projection consumes for backfill.
  """

  alias Apex.Billing.Invoice

  # Stand-in for Billing's store (in-process sample data).
  @invoices [
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

  @doc "Public read API: invoices for a business (tenant)."
  @spec list_invoices(String.t()) :: [Invoice.t()]
  def list_invoices(business_id) do
    Enum.filter(@invoices, &(&1.business_id == business_id))
  end
end
