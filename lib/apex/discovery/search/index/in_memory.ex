defmodule Apex.Discovery.Search.Index.InMemory do
  @moduledoc """
  In-memory `Apex.Discovery.Search.Index` adapter: a supervised GenServer holding
  `%{id => Document}`.

  Sufficient for the skeleton and the sample data; not intended for production
  scale (ETS or an external engine would replace it behind the same behaviour).

  Each function has a singleton form (arity matching the `Index` behaviour, backed
  by the process registered as `__MODULE__`) and a server-explicit form used by
  isolated tests.
  """

  use GenServer
  @behaviour Apex.Discovery.Search.Index

  alias Apex.Discovery.Search.{Document, Normalizer}

  # --- Lifecycle -------------------------------------------------------------

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl GenServer
  def init(state), do: {:ok, state}

  # --- Index behaviour (singleton) + server-explicit forms -------------------

  @impl Apex.Discovery.Search.Index
  def upsert(%Document{} = doc), do: upsert(__MODULE__, doc)
  def upsert(server, %Document{} = doc), do: GenServer.call(server, {:upsert, doc})

  @impl Apex.Discovery.Search.Index
  def delete(id) when is_binary(id), do: delete(__MODULE__, id)
  def delete(server, id) when is_binary(id), do: GenServer.call(server, {:delete, id})

  @impl Apex.Discovery.Search.Index
  def query(tenant_id, sources, normalized_query),
    do: query(__MODULE__, tenant_id, sources, normalized_query)

  def query(server, tenant_id, sources, normalized_query),
    do: GenServer.call(server, {:query, tenant_id, sources, normalized_query})

  @doc "Test helper: number of documents held."
  def count(server \\ __MODULE__), do: GenServer.call(server, :count)

  # --- Server ----------------------------------------------------------------

  @impl GenServer
  def handle_call({:upsert, doc}, _from, state) do
    {:reply, :ok, apply_if_newer(state, doc)}
  end

  def handle_call({:delete, id}, _from, state) do
    {:reply, :ok, Map.delete(state, id)}
  end

  def handle_call({:query, tenant_id, sources, nq}, _from, state) do
    source_set = MapSet.new(sources)

    docs =
      state
      |> Map.values()
      |> Enum.filter(fn doc ->
        doc.tenant_id == tenant_id and
          MapSet.member?(source_set, doc.source) and
          matches?(doc, nq)
      end)

    {:reply, {:ok, docs}, state}
  end

  def handle_call(:count, _from, state), do: {:reply, map_size(state), state}

  # --- Internals -------------------------------------------------------------

  # Apply-if-newer: a document is written only if no newer version is already
  # stored, so out-of-order events and backfill cannot regress fresher state.
  defp apply_if_newer(state, doc) do
    case Map.get(state, doc.id) do
      %Document{source_version: current} when current > doc.source_version -> state
      _ -> Map.put(state, doc.id, doc)
    end
  end

  defp matches?(_doc, ""), do: false

  defp matches?(doc, nq) do
    doc
    |> searchable_values()
    |> Enum.any?(fn value -> String.contains?(Normalizer.normalize(value), nq) end)
  end

  defp searchable_values(doc) do
    (Map.values(doc.search_terms) ++ [doc.title, doc.subtitle])
    |> Enum.reject(&is_nil/1)
  end
end
