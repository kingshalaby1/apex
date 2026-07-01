defmodule Apex.Discovery.Search.Index.InMemoryTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.Document
  alias Apex.Discovery.Search.Index.InMemory

  setup do
    name = :"ix_#{System.unique_integer([:positive])}"
    {:ok, pid} = InMemory.start_link(name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{ix: name}
  end

  defp doc(id, version, title, opts \\ []) do
    Document.new(
      [
        id: id,
        source: :invoices,
        tenant_id: "acme",
        title: title,
        search_terms: %{invoice_number: title},
        source_version: version
      ] ++ opts
    )
  end

  test "apply-if-newer: an older version cannot regress fresher state", %{ix: ix} do
    :ok = InMemory.upsert(ix, doc("invoice:x", 2, "INV-V2"))
    :ok = InMemory.upsert(ix, doc("invoice:x", 1, "INV-V1-STALE"))

    {:ok, [stored]} = InMemory.query(ix, "acme", [:invoices], "inv-v2")
    assert stored.source_version == 2
    assert stored.title == "INV-V2"
    assert InMemory.count(ix) == 1
  end

  test "apply-if-newer: a newer version replaces, equal version is idempotent", %{ix: ix} do
    :ok = InMemory.upsert(ix, doc("invoice:x", 1, "INV-V1"))
    :ok = InMemory.upsert(ix, doc("invoice:x", 3, "INV-V3"))
    :ok = InMemory.upsert(ix, doc("invoice:x", 3, "INV-V3"))

    {:ok, [stored]} = InMemory.query(ix, "acme", [:invoices], "inv-v3")
    assert stored.source_version == 3
    assert InMemory.count(ix) == 1
  end

  test "delete removes by id and is idempotent", %{ix: ix} do
    :ok = InMemory.upsert(ix, doc("invoice:x", 1, "INV-1"))
    :ok = InMemory.delete(ix, "invoice:x")
    :ok = InMemory.delete(ix, "invoice:x")
    assert InMemory.count(ix) == 0
  end

  test "query filters by tenant and source", %{ix: ix} do
    :ok = InMemory.upsert(ix, doc("invoice:acme", 1, "INV-A"))
    :ok = InMemory.upsert(ix, doc("invoice:desert", 1, "INV-D", tenant_id: "desert"))

    assert {:ok, [only]} = InMemory.query(ix, "acme", [:invoices], "inv-")
    assert only.tenant_id == "acme"

    assert {:ok, []} = InMemory.query(ix, "acme", [:trading_partners], "inv-")
  end
end
