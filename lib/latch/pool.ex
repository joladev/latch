defmodule Latch.Pool do
  @moduledoc false

  @default_pool_opts [
    conn_max_idle_time: 30_000,
    pool_max_idle_time: 60_000,
    size: 50
  ]

  def name(base) do
    :"latch_#{base}_pool"
  end

  def default_pool_opts do
    @default_pool_opts
  end

  def start_pool?(config) do
    name(config.name) == config.pool[:name]
  end
end
