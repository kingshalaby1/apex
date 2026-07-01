defmodule Apex.Discovery.Search do
  @moduledoc """
  Public entry point for the **search verb** of the Discovery context.

      Apex.Discovery.Search.query(scope, "Gulf", limit: 10, sources: [:trading_partners, :invoices])

  The pipeline: validate scope → normalise query → resolve sources → retrieve
  candidates from the index (per source, isolated) → authorise (tenant +
  permissions) → rank → group → assemble a `Response`. It reads only the search
  projection and never another context's data (constitution Principles I, II, IV).

  It always returns a `%Response{}`; a failing source degrades the response
  (`degraded? == true`, recorded in `errors`) rather than raising.

  ## Options

    * `:limit` — overall result cap (default 10)
    * `:sources` — list of source keys to search (default: all registered)
    * `:correlation_id` — trace id (generated if absent)
    * `:index` — index module implementing `Apex.Discovery.Search.Index`
      (default `Index.InMemory`); primarily a test seam
  """

  alias Apex.Discovery.Search.{
    Authorizer,
    Grouper,
    Index.InMemory,
    Normalizer,
    Ranker,
    Registry,
    Response,
    Scope,
    Telemetry
  }

  @default_limit 10
  @default_per_group 5

  @spec query(Scope.t(), String.t(), keyword()) :: Response.t()
  def query(scope, query_text, opts \\ [])

  def query(%Scope{} = scope, query_text, opts) when is_binary(query_text) do
    started_at = System.monotonic_time()
    correlation_id = opts[:correlation_id] || generate_correlation_id()
    limit = Keyword.get(opts, :limit) || @default_limit
    index = Keyword.get(opts, :index, InMemory)
    normalized_query = Normalizer.normalize(query_text)
    {sources, source_errors} = resolve_sources(Keyword.get(opts, :sources))

    {groups, errors} =
      if normalized_query == "" do
        {[], source_errors}
      else
        {candidates, retrieval_errors} =
          retrieve(index, scope.business_id, sources, normalized_query)

        groups =
          candidates
          |> Authorizer.authorize(scope)
          |> Ranker.rank(normalized_query)
          |> Grouper.group(limit: limit, per_group: @default_per_group)

        {groups, source_errors ++ retrieval_errors}
      end

    took_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    %Response{
      query: normalized_query,
      groups: groups,
      degraded?: errors != [],
      errors: errors,
      meta: %{
        limit: limit,
        took_ms: took_ms,
        sources: sources,
        correlation_id: correlation_id
      }
    }
    |> Telemetry.query_completed(scope)
  end

  # --- Source resolution -----------------------------------------------------

  defp resolve_sources(nil), do: {Registry.keys(), []}

  defp resolve_sources(requested) when is_list(requested) do
    known = Registry.keys()
    {valid, invalid} = Enum.split_with(requested, &(&1 in known))
    {valid, Enum.map(invalid, &%{source: &1, reason: :unknown_source})}
  end

  # --- Retrieval (per-source isolation for fail-safe partial results) --------

  defp retrieve(index, tenant_id, sources, normalized_query) do
    Enum.reduce(sources, {[], []}, fn source, {docs, errors} ->
      case safe_query(index, tenant_id, source, normalized_query) do
        {:ok, source_docs} -> {docs ++ source_docs, errors}
        {:error, reason} -> {docs, errors ++ [%{source: source, reason: reason}]}
      end
    end)
  end

  defp safe_query(index, tenant_id, source, normalized_query) do
    index.query(tenant_id, [source], normalized_query)
  rescue
    error -> {:error, Exception.message(error)}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp generate_correlation_id do
    "srch_" <> Integer.to_string(System.unique_integer([:positive]))
  end
end
