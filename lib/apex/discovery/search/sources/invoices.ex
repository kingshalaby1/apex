defmodule Apex.Discovery.Search.Sources.Invoices do
  @moduledoc """
  Search source adapter for the Billing context's invoices.

  Invoices are sensitive financial documents: `required_permissions` is
  `[:finance]`, and only scope-safe snippet fields are exposed. Holds the sample
  data for the skeleton.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Discovery.Search.Document

  @records [
    %{
      id: "inv_123",
      business_id: "acme",
      number: "INV-123",
      partner_name: "Gulf Trading",
      status: :overdue,
      version: 1,
      updated_at: ~U[2026-06-10 09:00:00Z]
    },
    %{
      id: "inv_222",
      business_id: "acme",
      number: "INV-222",
      partner_name: "Gulf Trading",
      status: :paid,
      version: 1,
      updated_at: ~U[2026-06-20 09:00:00Z]
    },
    %{
      id: "inv_999",
      business_id: "desert",
      number: "INV-999",
      partner_name: "Gulf Trading",
      status: :overdue,
      version: 1,
      updated_at: ~U[2026-06-15 09:00:00Z]
    }
  ]

  @impl true
  def source_key, do: :invoices

  @impl true
  def group_label, do: "Invoices"

  @impl true
  def type_weight, do: 0.8

  @impl true
  def to_document(inv) do
    Document.new(
      id: "invoice:#{inv.id}",
      source: :invoices,
      tenant_id: inv.business_id,
      required_permissions: [:finance],
      title: inv.number,
      subtitle: inv.partner_name,
      search_terms: %{invoice_number: inv.number, trading_partner_name: inv.partner_name},
      metadata: %{status: inv.status},
      url: "/business/#{inv.business_id}/invoices/#{inv.id}",
      updated_at: inv.updated_at,
      source_version: inv.version
    )
  end

  @impl true
  def fetch_all(tenant_id), do: Enum.filter(@records, &(&1.business_id == tenant_id))
end
