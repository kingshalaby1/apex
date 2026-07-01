defmodule Apex.Discovery.Search.Sources.PaymentRequests do
  @moduledoc """
  Search source adapter for the Remittance context's payment requests.

  Payment requests require `[:payments]` to view. Holds the sample data for the
  skeleton.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Discovery.Search.Document

  @records [
    %{
      id: "pr_111",
      business_id: "acme",
      number: "111",
      payer_name: "Gulf LLC",
      state: :active,
      version: 1,
      updated_at: ~U[2026-06-05 09:00:00Z]
    },
    %{
      id: "pr_222",
      business_id: "acme",
      number: "222",
      payer_name: "Gulf Trading",
      state: :expired,
      version: 1,
      updated_at: ~U[2026-06-12 09:00:00Z]
    }
  ]

  @impl true
  def source_key, do: :payment_requests

  @impl true
  def group_label, do: "Payment Requests"

  @impl true
  def type_weight, do: 0.6

  @impl true
  def to_document(pr) do
    Document.new(
      id: "payment_request:#{pr.id}",
      source: :payment_requests,
      tenant_id: pr.business_id,
      required_permissions: [:payments],
      title: pr.number,
      subtitle: pr.payer_name,
      search_terms: %{number: pr.number, payer_name: pr.payer_name},
      metadata: %{state: pr.state},
      url: "/business/#{pr.business_id}/payment-requests/#{pr.id}",
      updated_at: pr.updated_at,
      source_version: pr.version
    )
  end

  @impl true
  def fetch_all(tenant_id), do: Enum.filter(@records, &(&1.business_id == tenant_id))
end
