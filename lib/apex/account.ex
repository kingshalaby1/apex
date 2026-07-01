defmodule Apex.Account do
  @moduledoc """
  Account context — **owns business identity and trading-partner relationships**.

  Canonical records:

    * Business identity — the canonical business record, verification state and
      published profile.
    * Trading-partner relationships — relationship-scoped counterparty records
      and contact data (`Apex.Account.TradingPartner`).

  ## Boundary

  Account is the source of truth for these records. Other contexts must not read
  Account's internal tables; they use this **public API**. Writes persist and
  publish a domain event on `Apex.EventBus` (topic `:trading_partners`); Account
  does not know who consumes them (the search projection is one subscriber).
  """

  alias Apex.Account.TradingPartner
  alias Apex.EventBus

  @topic :trading_partners

  # --- Reads -----------------------------------------------------------------

  @doc "Public read API: trading partners for a business (tenant)."
  @spec list_trading_partners(String.t()) :: [TradingPartner.t()]
  def list_trading_partners(business_id) do
    TradingPartner.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end

  @doc "Fetch a single trading partner by id (or `nil`)."
  @spec get_trading_partner(String.t()) :: TradingPartner.t() | nil
  def get_trading_partner(id), do: TradingPartner.Store.get(id)

  # --- Writes (persist + emit a domain event) --------------------------------

  @doc "Create a trading partner, persist it, and announce `:created`."
  @spec create_trading_partner(map()) :: {:ok, TradingPartner.t()}
  def create_trading_partner(attrs) do
    partner = struct!(TradingPartner, attrs)
    TradingPartner.Store.put(partner)
    EventBus.publish(@topic, %{name: :created, record: partner})
    {:ok, partner}
  end

  @doc "Update a trading partner (bumping its version) and announce `:updated`."
  @spec update_trading_partner(String.t(), map()) ::
          {:ok, TradingPartner.t()} | {:error, :not_found}
  def update_trading_partner(id, attrs) do
    case TradingPartner.Store.get(id) do
      nil ->
        {:error, :not_found}

      partner ->
        updated = %{struct(partner, attrs) | version: partner.version + 1}
        TradingPartner.Store.put(updated)
        EventBus.publish(@topic, %{name: :updated, record: updated})
        {:ok, updated}
    end
  end

  @doc "Delete a trading partner and announce `:deleted`."
  @spec delete_trading_partner(String.t()) :: {:ok, TradingPartner.t()} | {:error, :not_found}
  def delete_trading_partner(id) do
    case TradingPartner.Store.get(id) do
      nil ->
        {:error, :not_found}

      partner ->
        TradingPartner.Store.delete(id)
        EventBus.publish(@topic, %{name: :deleted, record: partner})
        {:ok, partner}
    end
  end
end
