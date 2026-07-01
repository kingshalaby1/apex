defmodule Apex.Account.TradingPartner do
  @moduledoc """
  A trading-partner relationship record owned by the `Apex.Account` context.

  This is the context's own domain model — the source of truth. The search
  projection is derived from it (via a source adapter), never the other way round.
  """

  @enforce_keys [:id, :business_id, :name]
  defstruct [:id, :business_id, :name, :unn, :updated_at, verified: false, version: 1]

  @type t :: %__MODULE__{
          id: String.t(),
          business_id: String.t(),
          name: String.t(),
          unn: String.t() | nil,
          verified: boolean(),
          version: non_neg_integer(),
          updated_at: DateTime.t() | nil
        }
end
