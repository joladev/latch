defmodule Latch.NonceCache do
  @moduledoc false

  use GenServer

  @table_options [
    :set,
    :public,
    :named_table,
    read_concurrency: true,
    write_concurrency: true
  ]

  @default_sweep_interval :timer.minutes(2)
  @default_ttl_ms :timer.minutes(5)

  def get_nonce(config, session_id, origin) do
    key = {session_id, origin}

    case :ets.lookup(table(config), key) do
      [{^key, nonce, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, nonce}
        else
          :error
        end

      [] ->
        :error
    end
  end

  def put_nonce(config, session_id, origin, nonce, ttl_ms \\ @default_ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(table(config), {{session_id, origin}, nonce, expires_at})
    :ok
  end

  def row_count(config) do
    :ets.info(table(config), :size)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    config = Keyword.fetch!(opts, :config)
    name = Keyword.fetch!(opts, :name)
    table_name = :"latch_#{name}_nonce_cache"
    table = :ets.new(table_name, @table_options)

    sweep_after = Keyword.get(opts, :sweep_after, @default_sweep_interval)
    sweep_disabled = Keyword.get(opts, :sweep_disabled, false)

    schedule_sweep(sweep_after, sweep_disabled)

    {:ok,
     %{
       config: config,
       table: table,
       sweep_after: sweep_after,
       sweep_disabled: sweep_disabled
     }}
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    sweep(table(state.config))
    schedule_sweep(state.sweep_after, state.sweep_disabled)
    {:noreply, state}
  end

  defp schedule_sweep(sweep_after, sweep_disabled) do
    if not sweep_disabled do
      Process.send_after(self(), :sweep, sweep_after)
    end
  end

  defp sweep(table) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(table, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]}
    ])
  end

  defp table(config) do
    :"latch_#{config.name}_nonce_cache"
  end
end
