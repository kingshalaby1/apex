defmodule Apex.Remittance do
  @moduledoc """
  Remittance context — **owns payment obligations, payment links and payment
  requests**.

  Handles the collection workflow: payment-request state and payer/payee
  projections (`Apex.Remittance.PaymentRequest`).

  ## Boundary

  Remittance is the source of truth for payment requests. Other contexts must not
  read Remittance's internal tables; they use this **public API** (and, in a real
  system, Remittance's domain events). `list_payment_requests/1` is the read the
  search projection consumes for backfill.
  """

  alias Apex.Remittance.PaymentRequest

  # Stand-in for Remittance's store (in-process sample data).
  @payment_requests [
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

  @doc "Public read API: payment requests for a business (tenant)."
  @spec list_payment_requests(String.t()) :: [PaymentRequest.t()]
  def list_payment_requests(business_id) do
    Enum.filter(@payment_requests, &(&1.business_id == business_id))
  end
end
