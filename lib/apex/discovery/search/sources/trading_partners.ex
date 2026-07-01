defmodule Apex.Discovery.Search.Sources.TradingPartners do
  @moduledoc """
  Search source adapter for the Account context's trading-partner relationships.

  Pulls records from Account's **public API** (`Apex.Account.list_trading_partners/1`)
  for backfill and maps a `Apex.Account.TradingPartner` into a neutral `Document`.
  Trading partners are visible to all users of the business, so
  `required_permissions` is empty.
  """

  @behaviour Apex.Discovery.Search.Source

  alias Apex.Account
  alias Apex.Account.TradingPartner
  alias Apex.Discovery.Search.Document

  @impl true
  def source_key, do: :trading_partners

  @impl true
  def group_label, do: "Trading Partners"

  @impl true
  def type_weight, do: 1.0

  @impl true
  def to_document(%TradingPartner{} = tp) do
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
  def fetch_all(tenant_id), do: Account.list_trading_partners(tenant_id)
end
