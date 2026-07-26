defmodule Latch.Store.ETS do
  @moduledoc """
  Pre-built ETS Store for Latch. Does not maintain access tokens or in-progress requests
  across restarts. For a more reliable approach, create your own implementation of
  the Latch.Store behavior.

  TTL for requests is set on the Latch level, passed by the implementor as `request_ttl`,
  defaulting to 600s.
  """

  require Logger

  defmacro __using__(_) do
    quote do
      use GenServer

      alias Latch.Store.ETS, as: ETSStore

      require Logger

      @behaviour Latch.Store

      @sweep_interval_ms :timer.hours(24)

      @table_options [
        :public,
        :set,
        :named_table,
        {:read_concurrency, true}
      ]

      def put_request(state, request, ttl) do
        ETSStore.put_request(requests_table(), state, request, ttl)
      end

      def take_request(state) do
        ETSStore.take_request(requests_table(), state)
      end

      def fetch_session(did) do
        ETSStore.fetch_session(sessions_table(), did)
      end

      def put_session(did, session) do
        ETSStore.put_session(sessions_table(), did, session)
      end

      def delete_session(did) do
        ETSStore.delete_session(sessions_table(), did)
      end

      def update_session(did, fun) do
        GenServer.call(__MODULE__, {:update_session, did, fun})
      catch
        :exit, reason ->
          Logger.warning("Latch.Store.ETS implementation raised with: #{inspect(reason)}")
          {:error, :backend_error}
      end

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @impl GenServer
      def init(opts) do
        sweep_disabled = Keyword.get(opts, :sweep_disabled, false)
        sweep_interval_ms = Keyword.get(opts, :sweep_interval_ms, @sweep_interval_ms)

        requests = :ets.new(requests_table(), @table_options)
        sessions = :ets.new(sessions_table(), @table_options)

        schedule_sweep(sweep_disabled, sweep_interval_ms)

        {:ok,
         %{
           sweep_disabled: sweep_disabled,
           sweep_interval_ms: sweep_interval_ms,
           requests: requests,
           sessions: sessions
         }}
      end

      @impl GenServer
      def handle_call({:update_session, did, fun}, _from, state) do
        result = ETSStore.update_session(sessions_table(), did, fun)
        {:reply, result, state}
      end

      @impl GenServer
      def handle_info(:sweep, state) do
        schedule_sweep(state.sweep_disabled, state.sweep_interval_ms)

        {:noreply, state}
      end

      defp schedule_sweep(sweep_disabled, sweep_interval_ms) do
        if not sweep_disabled do
          now = System.monotonic_time(:second)
          :ets.select_delete(requests_table(), [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])

          Process.send_after(self(), :sweep, sweep_interval_ms)
        end
      end

      defp requests_table do
        :"#{__MODULE__}_requests"
      end

      defp sessions_table do
        :"#{__MODULE__}_sessions"
      end
    end
  end

  def put_request(ref, state, request, ttl) do
    sweep_after_timestamp = System.monotonic_time(:second) + ttl
    :ets.insert(ref, {state, request, sweep_after_timestamp})
    :ok
  end

  def take_request(ref, state) do
    case :ets.take(ref, state) do
      [] ->
        {:error, :not_found}

      [{^state, request, sweep_after_timestamp} | _] ->
        if sweep_after_timestamp > System.monotonic_time(:second) do
          {:ok, request}
        else
          {:error, :not_found}
        end
    end
  end

  def fetch_session(ref, did) do
    case :ets.lookup(ref, did) do
      [] -> {:error, :not_found}
      [{^did, session} | _] -> {:ok, session}
    end
  end

  def put_session(ref, did, session) do
    :ets.insert(ref, {did, session})
    :ok
  end

  def delete_session(ref, did) do
    :ets.delete(ref, did)
    :ok
  end

  def update_session(ref, did, fun) do
    with {:ok, session} <- fetch_session(ref, did) do
      with {:ok, session} <- fun.(session) do
        :ok = put_session(ref, did, session)
        {:ok, session}
      end
    end
  rescue
    error ->
      Logger.warning("Latch.Store.ETS implementation raised with: #{inspect(error)}")
      {:error, :backend_error}
  end
end
