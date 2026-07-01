defmodule Apex.Discovery.Search.Grouper do
  @moduledoc """
  Buckets ranked results into labelled groups and bounds them (spec FR-009/FR-018).

    * Groups are ordered by a **fixed source priority** (`type_weight`, descending),
      independent of per-query scores — so ordering is deterministic.
    * Each group is capped at `:per_group` (default 5).
    * The response is capped at `:limit` overall (default 10), consumed in group
      order so the highest-priority groups keep their results.

  Results arrive already ordered best-first (from the ranker); grouping preserves
  that order within each source.
  """

  alias Apex.Discovery.Search.{Group, Registry, Result}

  @default_limit 10
  @default_per_group 5

  @doc "Group, order and bound ranked results into `Group` structs."
  @spec group([Result.t()], keyword()) :: [Group.t()]
  def group(results, opts \\ []) do
    limit = Keyword.get(opts, :limit) || @default_limit
    per_group = Keyword.get(opts, :per_group) || @default_per_group

    results
    |> Enum.group_by(& &1.source)
    |> Enum.map(fn {source, rs} -> {source, Enum.take(rs, per_group)} end)
    |> Enum.sort_by(fn {source, _} -> type_weight(source) end, :desc)
    |> take_overall(limit)
    |> Enum.map(fn {source, rs} ->
      %Group{source: source, label: label(source), results: rs}
    end)
  end

  # Consume the overall budget in group order; drop groups that get nothing.
  defp take_overall(ordered_groups, limit) do
    {groups, _remaining} =
      Enum.flat_map_reduce(ordered_groups, limit, fn {source, rs}, remaining ->
        taken = Enum.take(rs, max(remaining, 0))
        {[{source, taken}], remaining - length(taken)}
      end)

    Enum.reject(groups, fn {_source, rs} -> rs == [] end)
  end

  defp type_weight(source) do
    case Registry.module(source) do
      nil -> 0.0
      mod -> mod.type_weight()
    end
  end

  defp label(source) do
    case Registry.module(source) do
      nil -> to_string(source)
      mod -> mod.group_label()
    end
  end
end
