defmodule Apex.Discovery.Search.Authorizer do
  @moduledoc """
  Enforces tenant isolation and permission gating before any result is returned
  (constitution Principles IV and V).

  Two stages, applied in order to candidate documents:

    1. **Tenant** — drop any document whose `tenant_id` is not the scope's
       `business_id`. (Defence in depth: the index already filters by tenant.)
    2. **Permission** — drop any document whose `required_permissions` are not all
       held by the scope. Denied results are **omitted entirely** (no stub).

  Documents carry only scope-safe fields, so what survives is safe to surface.
  """

  alias Apex.Discovery.Search.{Document, Scope}

  @doc "Return only the documents the scope is allowed to see."
  @spec authorize([Document.t()], Scope.t()) :: [Document.t()]
  def authorize(documents, %Scope{} = scope) do
    documents
    |> Enum.filter(&same_tenant?(&1, scope))
    |> Enum.filter(&permitted?(&1, scope))
  end

  defp same_tenant?(%Document{tenant_id: tenant_id}, %Scope{business_id: business_id}),
    do: tenant_id == business_id

  defp permitted?(%Document{required_permissions: required}, %Scope{} = scope),
    do: Scope.permits?(scope, required)
end
