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

  @doc "Public read API: invoices for a business (tenant)."
  @spec list_invoices(String.t()) :: [Invoice.t()]
  def list_invoices(business_id) do
    Invoice.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end
end
