defmodule Apex.Discovery.Search.Telemetry do
  @moduledoc """
  Thin observability seam (constitution: Observability).

  Names exactly where metrics, traces and audit attach. In the skeleton it logs;
  in production this is where `:telemetry.execute/3` and an audit sink would live.
  Every query carries a correlation id so a search can be traced end to end, and
  sensitive searches are auditable (who searched, within which business).
  """

  require Logger

  alias Apex.Discovery.Search.{Response, Scope}

  @doc "Emit a completion signal for a finished query and return the response unchanged."
  @spec query_completed(Response.t(), Scope.t()) :: Response.t()
  def query_completed(%Response{} = response, %Scope{} = scope) do
    Logger.debug(fn ->
      "[search] correlation=#{response.meta[:correlation_id]} " <>
        "business=#{scope.business_id} actor=#{scope.actor_id} " <>
        "q=#{inspect(response.query)} results=#{result_count(response)} " <>
        "degraded=#{response.degraded?} took_ms=#{response.meta[:took_ms]}"
    end)

    response
  end

  defp result_count(%Response{groups: groups}),
    do: Enum.reduce(groups, 0, fn g, acc -> acc + length(g.results) end)
end
