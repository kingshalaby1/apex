defmodule Apex.Billing do
  @moduledoc """
  Billing context — **owns invoices**.

  Invoices are legal commercial documents carrying payment-status signals
  (e.g. `:overdue`, `:paid`). Billing decides the canonical state of an invoice.

  ## Boundary

  Billing is the source of truth for invoices. Other contexts must not read
  Billing's internal tables. Billing collaborates by:

    * exposing a public API for the invoice data it chooses to publish, and
    * emitting domain events (e.g. `InvoiceCreated`, `InvoicePaid`,
      `InvoiceVoided`) for derived consumers such as the Discovery search index.

  ## Search participation

  Billing provides a search *source adapter* (see `Apex.Discovery.Source`) that
  maps an invoice into a neutral search document. Because invoices are sensitive
  financial documents, the adapter declares the permissions required to see a
  result and exposes only scope-safe snippet fields.
  """

  # Public API — added in a later step.
end
