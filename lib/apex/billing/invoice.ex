defmodule Apex.Billing.Invoice do
  @moduledoc """
  An invoice owned by the `Apex.Billing` context — a legal commercial document
  with a payment-status signal. This is the context's own domain model (source of
  truth); the search projection is derived from it.
  """

  @enforce_keys [:id, :business_id, :number]
  defstruct [:id, :business_id, :number, :partner_name, :status, :updated_at, version: 1]

  @type t :: %__MODULE__{
          id: String.t(),
          business_id: String.t(),
          number: String.t(),
          partner_name: String.t() | nil,
          status: atom(),
          version: non_neg_integer(),
          updated_at: DateTime.t() | nil
        }
end
