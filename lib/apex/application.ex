defmodule Apex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Apex.Discovery.Search.{Index.InMemory, Indexer}

  @impl true
  def start(_type, _args) do
    children = [
      # The in-memory search projection (Discovery's read model).
      InMemory
    ]

    opts = [strategy: :one_for_one, name: Apex.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Backfill the sample data into the projection (skeleton seeding). In a real
    # system this is a deploy-time backfill; live events keep it fresh thereafter.
    Indexer.seed()

    {:ok, pid}
  end
end
