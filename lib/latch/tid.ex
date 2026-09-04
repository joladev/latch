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

  @doc """
  Each TID encodes a timestamp and a 10 bit clock ID. This returns the
  timestamp part for you as a DateTime. Note that TIDs can be created
  using any date, and it does not necessarily match when it was created
  or have any relationship with the data the TID is used for.

  `tid` must be a valid tid, use `valid?/1` to validate first.

  Example:

      Latch.TID.to_datetime("3mup4bbh67n2g")
      iex> {:ok, ~U[2026-09-04 13:50:51.404467Z]}
  """
  def to_datetime(tid) when is_binary(tid) do
    microseconds = to_unix(tid)
    # 1788529851404467

    DateTime.from_unix(microseconds, :microsecond)
    # {:ok, ~U[2026-09-04 13:50:51.404467Z]}
  end

  @doc """
  Like `to_datetime/1` but raises if the datetime is invalid.
  """
  def to_datetime!(tid) when is_binary(tid) do
    {:ok, datetime} = to_datetime(tid)
    datetime
  end

  @doc """
  Each TID encodes a timestamp and a 10 bit clock ID. This returns the
  timestamp part for you in the unix microseconds format. Note that TIDs
  can be created using any date, and it does not necessarily match when
  it was created or have any relationship with the data the TID is used for.

  `tid` must be a valid tid, use `valid?/1` to validate first.
  """
  def to_unix(tid) when is_binary(tid) do
    # Keeping the sample run that I used to work this out
    # here as reference in case I need to come back to it.

    # reference tid: "3mup4bbh67n2g"
    codepoints = String.to_charlist(tid)
    # [51, 109, 117, 112, 52, 98, 98, 104, 54, 55, 110, 50, 103]
    mapped =
      Enum.map(codepoints, fn c ->
        {pos, 1} = :binary.match(@alphabet, <<c>>)
        pos
      end)

    # [1, 18, 26, 21, 2, 7, 7, 13, 4, 5, 19, 0, 12]

    int = Integer.undigits(mapped, 32)
    # 1831454567838174220

    # divide out the clock ID, leaving the timestamp
    div(int, @offset)
    # 1788529851404467
  end

  defp random_clock_id do
    :rand.uniform(@offset) - 1
  end

  defp now_μs do
    System.os_time(:microsecond)
  end
end
