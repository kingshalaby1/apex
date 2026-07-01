defmodule Apex.EventFlowTest do
  # async: false — exercises the app-wide event bus, stores and index. Uses a
  # uniquely-named invoice ("inv_flow" / "Zephyr" / "Umbra") that no other suite
  # queries, so it cannot affect their assertions.
  use ExUnit.Case, async: false

  alias Apex.Billing
  alias Apex.Discovery.Search
  alias Apex.Discovery.Search.{EventSubscriber, Scope}

  setup do
    on_exit(fn ->
      Billing.delete_invoice("inv_flow")
      GenServer.call(EventSubscriber, :sync)
    end)

    :ok
  end

  # Barrier: a reply to :sync means every event published before it has been
  # applied to the index (FIFO mailbox).
  defp sync, do: GenServer.call(EventSubscriber, :sync)

  defp result_ids(query) do
    Scope.new(business_id: "acme", permissions: [:finance])
    |> Search.query(query)
    |> Map.fetch!(:groups)
    |> Enum.flat_map(& &1.results)
    |> Enum.map(& &1.id)
  end

  defp create_flow_invoice do
    Billing.create_invoice(%{
      id: "inv_flow",
      business_id: "acme",
      number: "INV-FLOW",
      partner_name: "Zephyr Trading",
      status: :draft
    })
  end

  test "creating an invoice makes it searchable via the event bus" do
    refute "invoice:inv_flow" in result_ids("Zephyr")

    {:ok, _invoice} = create_flow_invoice()
    sync()

    assert "invoice:inv_flow" in result_ids("Zephyr")
  end

  test "updating an invoice is reflected in search" do
    {:ok, _} = create_flow_invoice()
    sync()
    assert "invoice:inv_flow" in result_ids("Zephyr")

    {:ok, _} = Billing.update_invoice("inv_flow", %{partner_name: "Umbra Corp"})
    sync()

    assert "invoice:inv_flow" in result_ids("Umbra")
    refute "invoice:inv_flow" in result_ids("Zephyr")
  end

  test "deleting an invoice removes it from search" do
    {:ok, _} = create_flow_invoice()
    sync()
    assert "invoice:inv_flow" in result_ids("Zephyr")

    {:ok, _} = Billing.delete_invoice("inv_flow")
    sync()

    refute "invoice:inv_flow" in result_ids("Zephyr")
  end
end
