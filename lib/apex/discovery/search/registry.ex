defmodule Apex.Discovery.Search.Registry do
  @moduledoc """
  The set of searchable sources known to global search.

  Mapping `source_key => module`. Adding a new searchable object type is a
  one-line change here plus a module implementing `Apex.Discovery.Search.Source`
  — the query pipeline is untouched (constitution Principle VI).

  Ledger is intentionally absent (documented v1 non-goal).
  """

  alias Apex.Discovery.Search.Sources.{TradingPartners, Invoices, PaymentRequests}

  @sources %{
    trading_partners: TradingPartners,
    invoices: Invoices,
    payment_requests: PaymentRequests
  }

  @doc "All registered source modules."
  @spec all() :: [module()]
  def all, do: Map.values(@sources)

  @doc "All registered source keys."
  @spec keys() :: [atom()]
  def keys, do: Map.keys(@sources)

  @doc "Fetch the module for a source key."
  @spec fetch(atom()) :: {:ok, module()} | :error
  def fetch(key), do: Map.fetch(@sources, key)

  @doc "The module for a source key, or `nil` if unknown."
  @spec module(atom()) :: module() | nil
  def module(key), do: Map.get(@sources, key)
end
