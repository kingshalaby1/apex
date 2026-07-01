defmodule Apex.Billing do
  @moduledoc """
  Billing context — **owns invoices**.

  Invoices are legal commercial documents carrying payment-status signals
  (e.g. `:overdue`, `:paid`). Billing decides the canonical state of an invoice
  (`Apex.Billing.Invoice`).

  ## Boundary

  Billing is the source of truth for invoices. Other contexts must not read
  Billing's internal tables; they use this **public API**. Writes persist to
  Billing's store **and publish a domain event** on `Apex.EventBus` (topic
  `:invoices`). Billing does not know who consumes those events — the Discovery
  search projection is one subscriber, kept fresh without Billing ever referencing
  it.
  """

  alias Apex.Billing.Invoice
  alias Apex.EventBus

  @topic :invoices

  # --- Reads -----------------------------------------------------------------

  @doc "Public read API: invoices for a business (tenant)."
  @spec list_invoices(String.t()) :: [Invoice.t()]
  def list_invoices(business_id) do
    Invoice.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end

  @doc "Fetch a single invoice by id (or `nil`)."
  @spec get_invoice(String.t()) :: Invoice.t() | nil
  def get_invoice(id), do: Invoice.Store.get(id)

  # --- Writes (persist + emit a domain event) --------------------------------

  @doc "Create an invoice, persist it, and announce `:created`."
  @spec create_invoice(map()) :: {:ok, Invoice.t()}
  def create_invoice(attrs) do
    invoice = struct!(Invoice, attrs)
    Invoice.Store.put(invoice)
    EventBus.publish(@topic, %{name: :created, record: invoice})
    {:ok, invoice}
  end

  @doc "Update an existing invoice (bumping its version) and announce `:updated`."
  @spec update_invoice(String.t(), map()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def update_invoice(id, attrs) do
    case Invoice.Store.get(id) do
      nil ->
        {:error, :not_found}

      invoice ->
        updated = %{struct(invoice, attrs) | version: invoice.version + 1}
        Invoice.Store.put(updated)
        EventBus.publish(@topic, %{name: :updated, record: updated})
        {:ok, updated}
    end
  end

  @doc "Delete an invoice and announce `:deleted`."
  @spec delete_invoice(String.t()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def delete_invoice(id) do
    case Invoice.Store.get(id) do
      nil ->
        {:error, :not_found}

      invoice ->
        Invoice.Store.delete(id)
        EventBus.publish(@topic, %{name: :deleted, record: invoice})
        {:ok, invoice}
    end
  end
end
