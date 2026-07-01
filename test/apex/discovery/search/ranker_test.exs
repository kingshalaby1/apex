defmodule Apex.Discovery.Search.RankerTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.{Document, Ranker}

  test "an exact identifier match outranks a loose text match, ignoring type weight" do
    invoice =
      Document.new(
        id: "invoice:inv_123",
        source: :invoices,
        tenant_id: "acme",
        title: "INV-123",
        search_terms: %{invoice_number: "INV-123"},
        updated_at: ~U[2026-01-01 00:00:00Z]
      )

    # A trading partner (higher type_weight, more recent) whose name merely contains
    # the query — must still rank below the exact invoice match.
    partner =
      Document.new(
        id: "trading_partner:tp_9",
        source: :trading_partners,
        tenant_id: "acme",
        title: "INV-123 Supplies",
        search_terms: %{name: "INV-123 Supplies"},
        updated_at: ~U[2026-06-01 00:00:00Z]
      )

    results = Ranker.rank([partner, invoice], "inv-123")

    assert hd(results).id == "invoice:inv_123"
    assert hd(results).score == 1.0
    assert hd(results).matched_fields == [:invoice_number]
  end

  test "recency breaks ties between equally relevant results" do
    older =
      Document.new(
        id: "invoice:old",
        source: :invoices,
        tenant_id: "acme",
        title: "INV-1",
        subtitle: "Gulf Trading",
        search_terms: %{trading_partner_name: "Gulf Trading"},
        updated_at: ~U[2026-01-01 00:00:00Z]
      )

    newer = %{older | id: "invoice:new", updated_at: ~U[2026-06-01 00:00:00Z]}

    results = Ranker.rank([older, newer], "gulf")
    assert Enum.map(results, & &1.id) == ["invoice:new", "invoice:old"]
  end

  test "non-matching documents are dropped" do
    doc =
      Document.new(
        id: "invoice:x",
        source: :invoices,
        tenant_id: "acme",
        title: "INV-9",
        search_terms: %{invoice_number: "INV-9"}
      )

    assert Ranker.rank([doc], "gulf") == []
  end
end
