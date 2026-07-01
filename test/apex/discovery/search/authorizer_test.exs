defmodule Apex.Discovery.Search.AuthorizerTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search.{Authorizer, Document, Scope}

  defp doc(id, tenant, required) do
    Document.new(
      id: id,
      source: :invoices,
      tenant_id: tenant,
      title: id,
      required_permissions: required,
      search_terms: %{k: id}
    )
  end

  test "drops documents from another tenant" do
    scope = Scope.new(business_id: "acme", permissions: [:finance])
    docs = [doc("acme_doc", "acme", []), doc("desert_doc", "desert", [])]

    kept = Authorizer.authorize(docs, scope)
    assert Enum.map(kept, & &1.id) == ["acme_doc"]
  end

  test "omits documents whose required permissions are not all held" do
    scope = Scope.new(business_id: "acme", permissions: [:payments])

    docs = [
      doc("open", "acme", []),
      doc("invoice", "acme", [:finance]),
      doc("payment", "acme", [:payments])
    ]

    kept_ids = docs |> Authorizer.authorize(scope) |> Enum.map(& &1.id)
    assert "open" in kept_ids
    assert "payment" in kept_ids
    refute "invoice" in kept_ids
  end

  test "keeps permission-gated documents when the scope holds the permission" do
    scope = Scope.new(business_id: "acme", permissions: [:finance])
    docs = [doc("invoice", "acme", [:finance])]

    assert [%Document{id: "invoice"}] = Authorizer.authorize(docs, scope)
  end
end
