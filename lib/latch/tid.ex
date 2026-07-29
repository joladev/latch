defmodule Latch.TID do
  @moduledoc """
  Timestamp identifiers, frequently used as record keys in atproto. Time-sortable,
  can be used as logical clocks within a system, and designed to reduce the risk
  of collisions.

  https://atproto.com/specs/tid
  """

  @alphabet "234567abcdefghijklmnopqrstuvwxyz"
  @valid_clock_id_range 0..1023
  @offset 1024

  @doc """
  Validates a given string against a regex to ensure it conforms with the spec.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(tid) when is_binary(tid) do
    String.match?(tid, ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/)
  end

  @doc """
  Generate a TID that encodes the current time and a random clock ID, making it
  unlikely (but not impossible) to result in collisions.

  ## Options

  * `:clock_id` - override the random clock ID
  * `:time_fun` - a function that returns the current time as microseconds

  Overriding both `:clock_id` and `:time_fun` allows you to create deterministic tests.
  """
  @spec now(keyword()) :: String.t()
  def now(opts \\ []) do
    clock_id = Keyword.get_lazy(opts, :clock_id, &random_clock_id/0)

    if clock_id not in @valid_clock_id_range do
      raise "invalid clock ID"
    end

    time_fun = Keyword.get(opts, :time_fun, &now_μs/0)

    shifted = time_fun.() * @offset
    timestamp = shifted + clock_id
    new(timestamp)
  end

  @doc """
  Generate a TID that encodes the given time and a random clock ID, making it
  unlikely (but not impossible) to result in collisions.

  Overriding `:clock_id` allows you to create deterministic tests.
  """
  @spec at_time(DateTime.t(), integer()) :: String.t()
  def at_time(%DateTime{} = datetime, clock_id \\ random_clock_id())
      when clock_id in @valid_clock_id_range do
    timestamp_μs = DateTime.to_unix(datetime, :microsecond) * @offset
    new(timestamp_μs + clock_id)
  end

  @doc """
  Takes a raw integer and formats it as a TID.

  In most cases you'll want to use the helpers `now` and `at_time`.
  """
  @spec new(non_neg_integer()) :: String.t()
  def new(int) when int in 0..0x7FFF_FFFF_FFFF_FFFF do
    int
    |> Integer.digits(32)
    |> Enum.map_join(&<<:binary.at(@alphabet, &1)>>)
    |> String.pad_leading(13, "2")
  end

  defp random_clock_id do
    :rand.uniform(@offset) - 1
  end

  defp now_μs do
    System.os_time(:microsecond)
  end
end
