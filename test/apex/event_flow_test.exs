defmodule Apex.EventFlowTest do
  # async: false — exercises the app-wide event bus, stores and index. Uses
  # uniquely-named records (Zephyr / Nimbus / Solara) that no other suite queries,
  # so they cannot affect their assertions.
  use ExUnit.Case, async: false

  alias Apex.{Account, Billing, Remittance}
  alias Apex.Discovery.Search
  alias Apex.Discovery.Search.{EventSubscriber, Scope}

  setup do
    on_exit(fn ->
      Billing.delete_invoice("inv_flow")
      Account.delete_trading_partner("tp_flow")
      Remittance.delete_payment_request("pr_flow")
      GenServer.call(EventSubscriber, :sync)
    end)

    :ok
  end

  # Barrier: a reply to :sync means every event published before it has been
  # applied to the index (FIFO mailbox).
  defp sync, do: GenServer.call(EventSubscriber, :sync)

  defp result_ids(query) do
    Scope.new(business_id: "acme", permissions: [:finance, :payments])
    |> Search.query(query)
    |> Map.fetch!(:groups)
    |> Enum.flat_map(& &1.results)
    |> Enum.map(& &1.id)
  end

  describe "invoices (Billing)" do
    defp create_invoice do
      Billing.create_invoice(%{
        id: "inv_flow",
        business_id: "acme",
        number: "INV-FLOW",
        partner_name: "Zephyr Trading",
        status: :draft
      })
    end

    test "create makes it searchable" do
      refute "invoice:inv_flow" in result_ids("Zephyr")
      {:ok, _} = create_invoice()
      sync()
      assert "invoice:inv_flow" in result_ids("Zephyr")
    end

    test "update is reflected" do
      {:ok, _} = create_invoice()
      sync()

      {:ok, _} = Billing.update_invoice("inv_flow", %{partner_name: "Umbra Corp"})
      sync()

      assert "invoice:inv_flow" in result_ids("Umbra")
      refute "invoice:inv_flow" in result_ids("Zephyr")
    end

    test "delete removes it" do
      {:ok, _} = create_invoice()
      sync()
      assert "invoice:inv_flow" in result_ids("Zephyr")

      {:ok, _} = Billing.delete_invoice("inv_flow")
      sync()
      refute "invoice:inv_flow" in result_ids("Zephyr")
    end
  end

  describe "trading partners (Account)" do
    defp create_partner do
      Account.create_trading_partner(%{
        id: "tp_flow",
        business_id: "acme",
        name: "Nimbus Partners",
        unn: "9000000009"
      })
    end

    test "create makes it searchable" do
      refute "trading_partner:tp_flow" in result_ids("Nimbus")
      {:ok, _} = create_partner()
      sync()
      assert "trading_partner:tp_flow" in result_ids("Nimbus")
    end

    test "delete removes it" do
      {:ok, _} = create_partner()
      sync()
      assert "trading_partner:tp_flow" in result_ids("Nimbus")

      {:ok, _} = Account.delete_trading_partner("tp_flow")
      sync()
      refute "trading_partner:tp_flow" in result_ids("Nimbus")
    end
  end

  describe "payment requests (Remittance)" do
    defp create_request do
      Remittance.create_payment_request(%{
        id: "pr_flow",
        business_id: "acme",
        number: "PR-FLOW",
        payer_name: "Solara Group",
        state: :active
      })
    end

    test "create makes it searchable" do
      refute "payment_request:pr_flow" in result_ids("Solara")
      {:ok, _} = create_request()
      sync()
      assert "payment_request:pr_flow" in result_ids("Solara")
    end

    test "delete removes it" do
      {:ok, _} = create_request()
      sync()
      assert "payment_request:pr_flow" in result_ids("Solara")

      {:ok, _} = Remittance.delete_payment_request("pr_flow")
      sync()
      refute "payment_request:pr_flow" in result_ids("Solara")
    end
  end
end
