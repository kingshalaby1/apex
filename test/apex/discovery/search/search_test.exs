defmodule Apex.Discovery.Search.FlakyIndex do
  @moduledoc "Test index double: fails for :payment_requests, delegates the rest to the seeded index."
  alias Apex.Discovery.Search.Index.InMemory

  def query(_tenant_id, [:payment_requests], _nq),
    do: raise("payment requests source unavailable")

  def query(tenant_id, sources, nq), do: InMemory.query(tenant_id, sources, nq)
end

defmodule Apex.Discovery.SearchTest do
  use ExUnit.Case, async: true

  alias Apex.Discovery.Search
  alias Apex.Discovery.Search.{FlakyIndex, Scope}

  defp acme(perms \\ [:finance, :payments]),
    do: Scope.new(business_id: "acme", actor_id: "u", permissions: perms)

  defp desert(perms \\ [:finance, :payments]),
    do: Scope.new(business_id: "desert", permissions: perms)

  defp result_ids(response) do
    response.groups |> Enum.flat_map(& &1.results) |> Enum.map(& &1.id)
  end

  defp group_sources(response), do: Enum.map(response.groups, & &1.source)

  describe "US1 - grouped, tenant-scoped search" do
    test "acme 'Gulf' returns labelled groups with only acme records" do
      response = Search.query(acme(), "Gulf")

      assert Enum.map(response.groups, & &1.label) ==
               ["Trading Partners", "Invoices", "Payment Requests"]

      ids = result_ids(response)
      assert "trading_partner:tp_1" in ids
      assert "trading_partner:tp_2" in ids
      assert "invoice:inv_123" in ids
      assert "invoice:inv_222" in ids
      assert "payment_request:pr_111" in ids
      assert "payment_request:pr_222" in ids

      # No desert records leak into an acme search.
      refute "trading_partner:tp_3" in ids
      refute "invoice:inv_999" in ids
      refute response.degraded?
    end

    test "desert 'Gulf' sees only desert records, never acme's" do
      ids = Search.query(desert(), "Gulf") |> result_ids()

      assert "trading_partner:tp_3" in ids
      assert "invoice:inv_999" in ids

      for acme_id <- ~w(trading_partner:tp_1 trading_partner:tp_2 invoice:inv_123 invoice:inv_222
                        payment_request:pr_111 payment_request:pr_222) do
        refute acme_id in ids
      end
    end

    test "a blank query returns a well-formed empty response" do
      response = Search.query(acme(), "   ")
      assert response.groups == []
      refute response.degraded?
      assert response.errors == []
    end
  end

  describe "US2 - permission redaction (omit)" do
    test "without :finance, invoices are omitted entirely" do
      response = Search.query(acme([:payments]), "INV-123")
      assert result_ids(response) == []
      refute :invoices in group_sources(response)
    end

    test "without :payments, payment requests are omitted" do
      response = Search.query(acme([:finance]), "Gulf")
      refute :payment_requests in group_sources(response)
      assert :invoices in group_sources(response)
    end
  end

  describe "US3 - exact identifier ranking" do
    test "'INV-123' returns the invoice as the top result" do
      response = Search.query(acme(), "INV-123")
      assert hd(result_ids(response)) == "invoice:inv_123"
    end
  end

  describe "US4 - source filtering" do
    test "restricting to [:trading_partners] returns only that group" do
      response = Search.query(acme(), "Gulf", sources: [:trading_partners])
      assert group_sources(response) == [:trading_partners]
    end

    test "an unknown source is recorded as an error, not a crash" do
      response = Search.query(acme(), "Gulf", sources: [:trading_partners, :ledger])
      assert response.degraded?
      assert Enum.any?(response.errors, &(&1.source == :ledger))
      assert group_sources(response) == [:trading_partners]
    end
  end

  describe "US5 - fail-safe partial results" do
    test "a failing source degrades the response but healthy sources still return" do
      response = Search.query(acme(), "Gulf", index: FlakyIndex)

      assert response.degraded?
      assert Enum.any?(response.errors, &(&1.source == :payment_requests))
      assert :trading_partners in group_sources(response)
      assert :invoices in group_sources(response)
      refute :payment_requests in group_sources(response)
    end
  end
end
