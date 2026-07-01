defmodule Apex.Discovery.Search.Sources.TradingPartners do
  @moduledoc """
  Search source adapter for the Account context's trading-partner relationships.

  Trading partners are visible to all users of the business, so
  `required_permissions` is empty. Holds the sample data for the skeleton.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Discovery.Search.Document

  @records [
    %{
      id: "tp_1",
      business_id: "acme",
      name: "Gulf Trading",
      unn: "7000000001",
      verified: true,
      version: 1,
      updated_at: ~U[2026-06-01 09:00:00Z]
    },
    %{
      id: "tp_2",
      business_id: "acme",
      name: "Gulf LLC",
      unn: "7000000002",
      verified: false,
      version: 1,
      updated_at: ~U[2026-06-02 09:00:00Z]
    },
    %{
      id: "tp_3",
      business_id: "desert",
      name: "Gulf Trading",
      unn: "7000000001",
      verified: true,
      version: 1,
      updated_at: ~U[2026-06-01 09:00:00Z]
    }
  ]

  @impl true
  def source_key, do: :trading_partners

  @impl true
  def group_label, do: "Trading Partners"

  @impl true
  def type_weight, do: 1.0

  @impl true
  def to_document(tp) do
    Document.new(
      id: "trading_partner:#{tp.id}",
      source: :trading_partners,
      tenant_id: tp.business_id,
      required_permissions: [],
      title: tp.name,
      subtitle: "UNN #{tp.unn}",
      search_terms: %{name: tp.name, unn: tp.unn},
      metadata: %{verified: tp.verified},
      url: "/business/#{tp.business_id}/trading-partners/#{tp.id}",
      updated_at: tp.updated_at,
      source_version: tp.version
    )
  end

  @impl true
  def fetch_all(tenant_id), do: Enum.filter(@records, &(&1.business_id == tenant_id))
end
