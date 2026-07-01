defmodule Apex.Discovery.Search.IndexerTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.{Document, Indexer}
  alias Apex.Discovery.Search.Index.InMemory
  alias Apex.Discovery.Search.Sources.Invoices

  setup do
    name = :"ix_#{System.unique_integer([:positive])}"
    {:ok, pid} = InMemory.start_link(name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{ix: name}
  end

  test "reindex backfills a source for a tenant", %{ix: ix} do
    :ok = Indexer.reindex(Invoices, "acme", ix)

    # acme has two invoices in the sample data; desert's inv_999 is not loaded here.
    assert InMemory.count(ix) == 2
    assert {:ok, results} = InMemory.query(ix, "acme", [:invoices], "inv-")
    ids = Enum.map(results, & &1.id)
    assert "invoice:inv_123" in ids
    assert "invoice:inv_222" in ids
  end

  test "a stale backfill cannot regress a fresher live update", %{ix: ix} do
    # A live update lands first with a higher version...
    fresh =
      Document.new(
        id: "invoice:inv_123",
        source: :invoices,
        tenant_id: "acme",
        title: "INV-123",
        search_terms: %{invoice_number: "INV-123"},
        metadata: %{status: :paid},
        source_version: 5
      )

    :ok = InMemory.upsert(ix, fresh)

    # ...then a backfill replays the source record at version 1.
    :ok = Indexer.reindex(Invoices, "acme", ix)

    {:ok, results} = InMemory.query(ix, "acme", [:invoices], "inv-123")
    stored = Enum.find(results, &(&1.id == "invoice:inv_123"))
    assert stored.source_version == 5
    assert stored.metadata == %{status: :paid}
  end

  test "apply/2 handles upsert and delete events", %{ix: ix} do
    record = %{
      id: "inv_123",
      business_id: "acme",
      number: "INV-123",
      partner_name: "Gulf Trading",
      status: :overdue,
      version: 2,
      updated_at: ~U[2026-06-10 09:00:00Z]
    }

    :ok = Indexer.apply(%{type: :upsert, source: :invoices, record: record}, ix)
    assert InMemory.count(ix) == 1

    :ok = Indexer.apply(%{type: :delete, id: "invoice:inv_123"}, ix)
    assert InMemory.count(ix) == 0
  end
end
