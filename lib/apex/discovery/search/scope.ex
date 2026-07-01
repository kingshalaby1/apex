defmodule Apex.Discovery.Search.Scope do
  @moduledoc """
  The authorisation context of a search caller.

  A `Scope` is the trust boundary for a query. It is derived **server-side** from
  the authenticated session (never from client input) and answers three questions
  before any result is returned:

    * **Which tenant?** `business_id` — the mandatory tenant key. Every candidate
      document is filtered to this business.
    * **Who is asking?** `actor_id` — the user, carried for audit/observability.
    * **What may they see?** `permissions` — the set of coarse permission grants
      (e.g. `:finance`, `:payments`) checked against each document's
      `required_permissions`.

  `locale` ("en" / "ar") influences text normalisation and display; it does not
  affect authorisation.

  Version one uses **coarse, role-style permissions** (tenant + permission set),
  which is exactly what the sample data requires. Per-record ACLs are a
  deliberate non-goal (see the architecture document).
  """

  @enforce_keys [:business_id]
  defstruct business_id: nil,
            actor_id: nil,
            permissions: MapSet.new(),
            locale: "en"

  @type permission :: atom()

  @type t :: %__MODULE__{
          business_id: String.t(),
          actor_id: String.t() | nil,
          permissions: MapSet.t(permission()),
          locale: String.t()
        }

  @doc """
  Builds a `Scope`, normalising `permissions` to a `MapSet` and defaulting
  `locale`. Raises if `business_id` is absent — a query must never run untenanted.
  """
  @spec new(Enumerable.t()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    business_id =
      Map.get(attrs, :business_id) ||
        raise ArgumentError, "scope requires :business_id — a query must never run untenanted"

    %__MODULE__{
      business_id: business_id,
      actor_id: Map.get(attrs, :actor_id),
      permissions: attrs |> Map.get(:permissions, []) |> to_permission_set(),
      locale: Map.get(attrs, :locale, "en")
    }
  end

  @doc """
  Returns `true` only if the scope grants **every** permission in `required`.
  An empty requirement is always permitted (the document is not permission-gated).
  """
  @spec permits?(t(), [permission()]) :: boolean()
  def permits?(%__MODULE__{permissions: granted}, required) when is_list(required) do
    Enum.all?(required, &MapSet.member?(granted, &1))
  end

  defp to_permission_set(%MapSet{} = set), do: set
  defp to_permission_set(list) when is_list(list), do: MapSet.new(list)
end
