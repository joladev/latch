defmodule Latch.TestStore do
  @moduledoc false

  @behaviour Latch.Store

  alias Latch.Request
  alias Latch.Session

  @requests_key {__MODULE__, :requests}
  @sessions_key {__MODULE__, :sessions}

  def put_request(state, %Request{} = request, ttl_seconds) do
    requests = Process.get(@requests_key, %{})
    Process.put(@requests_key, Map.put(requests, state, request))
    send(self(), {:request_stored, state, request, ttl_seconds})
    :ok
  end

  def take_request(state) do
    requests = Process.get(@requests_key, %{})

    case Map.pop(requests, state) do
      {nil, _requests} ->
        {:error, :not_found}

      {%Request{} = request, remaining_requests} ->
        Process.put(@requests_key, remaining_requests)
        {:ok, request}
    end
  end

  def delete_expired_requests(_max_age_seconds), do: :ok

  def fetch_session(did) do
    case Process.get(@sessions_key, %{}) do
      %{^did => %Session{} = session} -> {:ok, session}
      _ -> {:error, :not_found}
    end
  end

  def put_session(did, %Session{} = session) do
    sessions = Process.get(@sessions_key, %{})
    Process.put(@sessions_key, Map.put(sessions, did, session))
    :ok
  end

  def delete_session(did) do
    sessions = Process.get(@sessions_key, %{})
    Process.put(@sessions_key, Map.delete(sessions, did))
    :ok
  end

  def update_session(did, fun) do
    with {:ok, session} <- fetch_session(did),
         {:ok, %Session{} = updated_session} <- fun.(session),
         :ok <- put_session(did, updated_session) do
      {:ok, updated_session}
    end
  end
end
