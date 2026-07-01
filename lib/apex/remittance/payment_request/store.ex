defmodule Apex.Remittance.PaymentRequest.Store do
  @moduledoc false
  # In-memory stand-in for the Remittance datastore — the "table" of payment
  # requests. Swap `all/0` for a real Repo query when persistence is introduced;
  # the context (Apex.Remittance) is the only caller.

  alias Apex.Remittance.PaymentRequest

  @records [
    %PaymentRequest{
      id: "pr_111",
      business_id: "acme",
      number: "111",
      payer_name: "Gulf LLC",
      state: :active,
      version: 1,
      updated_at: ~U[2026-06-05 09:00:00Z]
    },
    %PaymentRequest{
      id: "pr_222",
      business_id: "acme",
      number: "222",
      payer_name: "Gulf Trading",
      state: :expired,
      version: 1,
      updated_at: ~U[2026-06-12 09:00:00Z]
    }
  ]

  @spec all() :: [PaymentRequest.t()]
  def all, do: @records
end
