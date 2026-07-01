defmodule Apex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Apex.Discovery.Search.{EventSubscriber, Index.InMemory, Indexer}

  @impl true
  def start(_type, _args) do
    children = [
      # Domain-event bus (shared infrastructure, owned by no context).
      {Registry, keys: :duplicate, name: Apex.EventBus.Registry},
      # Billing's stateful invoice store (source of truth for the CRUD example).
      Apex.Billing.Invoice.Store,
      # The in-memory search projection (Discovery's read model).
      InMemory,
      # Subscribes to source events and projects them into the index.
      EventSubscriber
    ]

    opts = [strategy: :one_for_one, name: Apex.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Backfill the sample data into the projection (skeleton seeding). In a real
    # system this is a deploy-time backfill; live events keep it fresh thereafter.
    Indexer.seed()

    {:ok, pid}
  end
end
