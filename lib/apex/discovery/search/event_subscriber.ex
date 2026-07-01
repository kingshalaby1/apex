defmodule Apex.Discovery.Search.EventSubscriber do
  @moduledoc """
  Bridges source-context domain events to the search index.

  On start it subscribes (via `Apex.EventBus`) to every registered source's topic.
  When a context announces a change, this process **translates the domain event
  into an index operation** and hands it to the `Indexer` — created/updated →
  upsert, deleted → delete. This is where "an invoice changed" becomes "reindex the
  invoices source", keeping that mapping on the Discovery side; the source contexts
  stay unaware of search.

  Delivery is asynchronous (Principle III). Tests can call
  `GenServer.call(subscriber, :sync)` as a barrier: because the mailbox is FIFO, a
  reply to `:sync` means every event published before it has been applied.
  """

  use GenServer

  alias Apex.Discovery.Search.{Indexer, Registry}
  alias Apex.EventBus

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_opts) do
    Enum.each(Registry.keys(), &EventBus.subscribe/1)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:event, source, %{name: name, record: record}}, state) do
    apply_event(source, name, record)
    {:noreply, state}
  end

  @impl true
  def handle_call(:sync, _from, state), do: {:reply, :ok, state}

  defp apply_event(source, name, record) when name in [:created, :updated] do
    Indexer.apply(%{type: :upsert, source: source, record: record})
  end

  defp apply_event(source, :deleted, record) do
    Indexer.apply(%{type: :delete, source: source, record: record})
  end
end
