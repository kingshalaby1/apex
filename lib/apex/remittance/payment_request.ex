defmodule Apex.Remittance.PaymentRequest do
  @moduledoc """
  A payment request owned by the `Apex.Remittance` context — part of the
  collection workflow, with a payer/payee projection and a state
  (e.g. `:active`, `:expired`). Source of truth for the search projection.
  """

  @enforce_keys [:id, :business_id, :number]
  defstruct [:id, :business_id, :number, :payer_name, :state, :updated_at, version: 1]

  @type t :: %__MODULE__{
          id: String.t(),
          business_id: String.t(),
          number: String.t(),
          payer_name: String.t() | nil,
          state: atom(),
          version: non_neg_integer(),
          updated_at: DateTime.t() | nil
        }
end
