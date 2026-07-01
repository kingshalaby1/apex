defmodule ApexTest do
  use ExUnit.Case
  doctest Apex

  test "the five bounded contexts are defined" do
    for context <- [
          Apex.Account,
          Apex.Billing,
          Apex.Remittance,
          Apex.Ledger,
          Apex.Discovery
        ] do
      assert Code.ensure_loaded?(context)
    end
  end
end
