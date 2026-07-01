defmodule Apex.Discovery.Search.Sources.PaymentRequests do
  @moduledoc """
  Search source adapter for the Remittance context's payment requests.

  Pulls records from Remittance's **public API**
  (`Apex.Remittance.list_payment_requests/1`) for backfill and maps a
  `Apex.Remittance.PaymentRequest` into a neutral `Document`. Payment requests
  require `[:payments]` to view.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Discovery.Search.Document
  alias Apex.Remittance
  alias Apex.Remittance.PaymentRequest

  @impl true
  def source_key, do: :payment_requests

  @impl true
  def group_label, do: "Payment Requests"

  @impl true
  def type_weight, do: 0.6

  @impl true
  def to_document(%PaymentRequest{} = pr) do
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
  def fetch_all(tenant_id), do: Remittance.list_payment_requests(tenant_id)
end
