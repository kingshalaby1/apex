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

  @doc "Public read API: payment requests for a business (tenant)."
  @spec list_payment_requests(String.t()) :: [PaymentRequest.t()]
  def list_payment_requests(business_id) do
    PaymentRequest.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end
end
