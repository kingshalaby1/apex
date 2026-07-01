defmodule Apex.Discovery.Search.StructsTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.{Scope, Document}

  describe "Scope.new/1" do
    test "requires a business_id — a query must never run untenanted" do
      assert_raise ArgumentError, fn -> Scope.new(%{}) end
    end

    test "normalises permissions to a MapSet and defaults locale" do
      scope = Scope.new(business_id: "acme", actor_id: "user_42", permissions: [:finance])

      assert scope.business_id == "acme"
      assert %MapSet{} = scope.permissions
      assert scope.locale == "en"
    end

    test "permits? is true only when every required permission is granted" do
      scope = Scope.new(business_id: "acme", permissions: [:finance, :payments])

      assert Scope.permits?(scope, [:finance])
      assert Scope.permits?(scope, [:finance, :payments])
      assert Scope.permits?(scope, [])
      refute Scope.permits?(scope, [:admin])
      refute Scope.permits?(scope, [:finance, :admin])
    end
  end

  describe "Document.new/1" do
    test "requires id, source, tenant_id and title, and stamps indexed_at" do
      doc =
        Document.new(
          id: "invoice:inv_123",
          source: :invoices,
          tenant_id: "acme",
          title: "INV-123",
          required_permissions: [:finance],
          search_terms: %{invoice_number: "inv-123", trading_partner_name: "gulf trading"}
        )

      assert doc.id == "invoice:inv_123"
      assert doc.source == :invoices
      assert doc.tenant_id == "acme"
      assert doc.required_permissions == [:finance]
      assert doc.source_version == 0
      assert %DateTime{} = doc.indexed_at
    end

    test "raises when a required key is missing" do
      assert_raise ArgumentError, fn ->
        Document.new(id: "x", source: :invoices, title: "X")
      end
    end
  end
end
