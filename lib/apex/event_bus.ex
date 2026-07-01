defmodule Apex.EventBus do
  @moduledoc """
  Minimal in-process publish/subscribe bus — shared infrastructure owned by **no**
  bounded context.

  It is the seam that lets source contexts announce domain events without knowing
  who consumes them: a context `publish/2`es to a topic; interested processes
  (e.g. Discovery's search `EventSubscriber`) `subscribe/1` to it. Neither side
  references the other — they only share this bus.

  Backed by Elixir's built-in `Registry` in `:duplicate` mode (zero dependencies,
  single node). Delivery is **asynchronous**: `publish/2` sends each subscriber a
  message and returns immediately, so consumers catch up eventually — matching the
  "eventual consistency across contexts" principle. The wrapper keeps the
  transport swappable (e.g. `Phoenix.PubSub`) without changing callers.

  Started via `{Registry, keys: :duplicate, name: Apex.EventBus.Registry}` in the
  application supervision tree.
  """

  @registry __MODULE__.Registry

  @doc "Subscribe the calling process to `topic`. It will receive `{:event, topic, event}`."
  @spec subscribe(term()) :: :ok
  def subscribe(topic) do
    {:ok, _} = Registry.register(@registry, topic, nil)
    :ok
  end

  @doc "Publish `event` to every subscriber of `topic` (asynchronous, fire-and-forget)."
  @spec publish(term(), term()) :: :ok
  def publish(topic, event) do
    Registry.dispatch(@registry, topic, fn subscribers ->
      Enum.each(subscribers, fn {pid, _} -> send(pid, {:event, topic, event}) end)
    end)
  end
end
