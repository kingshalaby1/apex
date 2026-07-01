defmodule Apex.Remittance do
  @moduledoc """
  Remittance context — **owns payment obligations, payment links and payment
  requests**.

  Handles the collection workflow: payment-request state and payer/payee
  projections (e.g. `:active`, `:expired`).

  ## Boundary

  Remittance is the source of truth for payment requests. Other contexts must not
  read Remittance's internal tables. Remittance collaborates by:

    * exposing a public API for the data it chooses to publish, and
    * emitting domain events (e.g. `PaymentRequestCreated`,
      `PaymentRequestStateChanged`) for derived consumers such as the Discovery
      search index.

  ## Search participation

  Remittance provides a search *source adapter* (see `Apex.Discovery.Source`) that
  maps a payment request into a neutral search document. Payment requests are one
  of the version-one searchable sources.
  """

  # Public API — added in a later step.
end
