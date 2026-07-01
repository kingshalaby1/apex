defmodule Apex.Remittance do
  @moduledoc """
  Remittance context — **owns payment obligations, payment links and payment
  requests**.

  Handles the collection workflow: payment-request state and payer/payee
  projections (`Apex.Remittance.PaymentRequest`).

  ## Boundary

  Remittance is the source of truth for payment requests. Other contexts must not
  read Remittance's internal tables; they use this **public API**. Writes persist
  and publish a domain event on `Apex.EventBus` (topic `:payment_requests`);
  Remittance does not know who consumes them (the search projection is one
  subscriber).
  """

  alias Apex.EventBus
  alias Apex.Remittance.PaymentRequest

  @topic :payment_requests

  # --- Reads -----------------------------------------------------------------

  @doc "Public read API: payment requests for a business (tenant)."
  @spec list_payment_requests(String.t()) :: [PaymentRequest.t()]
  def list_payment_requests(business_id) do
    PaymentRequest.Store.all()
    |> Enum.filter(&(&1.business_id == business_id))
  end

  @doc "Fetch a single payment request by id (or `nil`)."
  @spec get_payment_request(String.t()) :: PaymentRequest.t() | nil
  def get_payment_request(id), do: PaymentRequest.Store.get(id)

  # --- Writes (persist + emit a domain event) --------------------------------

  @doc "Create a payment request, persist it, and announce `:created`."
  @spec create_payment_request(map()) :: {:ok, PaymentRequest.t()}
  def create_payment_request(attrs) do
    request = struct!(PaymentRequest, attrs)
    PaymentRequest.Store.put(request)
    EventBus.publish(@topic, %{name: :created, record: request})
    {:ok, request}
  end

  @doc "Update a payment request (bumping its version) and announce `:updated`."
  @spec update_payment_request(String.t(), map()) ::
          {:ok, PaymentRequest.t()} | {:error, :not_found}
  def update_payment_request(id, attrs) do
    case PaymentRequest.Store.get(id) do
      nil ->
        {:error, :not_found}

      request ->
        updated = %{struct(request, attrs) | version: request.version + 1}
        PaymentRequest.Store.put(updated)
        EventBus.publish(@topic, %{name: :updated, record: updated})
        {:ok, updated}
    end
  end

  @doc "Delete a payment request and announce `:deleted`."
  @spec delete_payment_request(String.t()) :: {:ok, PaymentRequest.t()} | {:error, :not_found}
  def delete_payment_request(id) do
    case PaymentRequest.Store.get(id) do
      nil ->
        {:error, :not_found}

      request ->
        PaymentRequest.Store.delete(id)
        EventBus.publish(@topic, %{name: :deleted, record: request})
        {:ok, request}
    end
  end
end
