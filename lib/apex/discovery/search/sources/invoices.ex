defmodule Apex.Discovery.Search.Sources.Invoices do
  @moduledoc """
  Search source adapter for the Billing context's invoices.

  The adapter is the seam between Billing and search: it pulls records from
  Billing's **public API** (`Apex.Billing.list_invoices/1`) for backfill and maps
  a `Apex.Billing.Invoice` into a neutral, scope-safe `Document`. The invoice data
  itself lives in Billing, not here. Invoices are sensitive, so
  `required_permissions` is `[:finance]` and only scope-safe fields are exposed.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Billing
  alias Apex.Billing.Invoice
  alias Apex.Discovery.Search.Document

  @impl true
  def source_key, do: :invoices

  @impl true
  def group_label, do: "Invoices"

  @impl true
  def type_weight, do: 0.8

  @impl true
  def to_document(%Invoice{} = invoice) do
    Document.new(
      id: "invoice:#{invoice.id}",
      source: :invoices,
      tenant_id: invoice.business_id,
      required_permissions: [:finance],
      title: invoice.number,
      subtitle: invoice.partner_name,
      search_terms: %{
        invoice_number: invoice.number,
        trading_partner_name: invoice.partner_name
      },
      metadata: %{status: invoice.status},
      url: "/business/#{invoice.business_id}/invoices/#{invoice.id}",
      updated_at: invoice.updated_at,
      source_version: invoice.version
    )
  end

  @impl true
  def fetch_all(tenant_id), do: Billing.list_invoices(tenant_id)
end
