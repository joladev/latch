defmodule Latch.TidTest do
  use ExUnit.Case, async: true

  alias Latch.TID

  describe "valid?/1" do
    test "validates" do
      # Examples from https://atproto.com/specs/tid
      assert TID.valid?(TID.now())
      assert TID.valid?("3jzfcijpj2z2a")
      assert TID.valid?("7777777777777")
      assert TID.valid?("3zzzzzzzzzzzz")
      assert TID.valid?("2222222222222")

      # not base32
      refute TID.valid?("3jzfcijpj2z21")
      refute TID.valid?("0000000000000")
      # case-sensitive
      refute TID.valid?("3JZFCIJPJ2Z2A")
      # too long/short
      refute TID.valid?("3jzfcijpj2z2aa")
      refute TID.valid?("3jzfcijpj2z2")
      refute TID.valid?("222")
      # legacy dash syntax *not* supported (TTTT-TTT-TTTT-CC)
      refute TID.valid?("3jzf-cij-pj2z-2a")
      # high bit can't be set
      refute TID.valid?("zzzzzzzzzzzzz")
      refute TID.valid?("kjzfcijpj2z2a")
    end
  end

  describe "now/0" do
    test "generates a new TID" do
      assert TID.valid?(TID.now())
    end

    test "can be made deterministic" do
      assert TID.now(time_fun: fn -> 1_785_308_213_234_023 end, clock_id: 1000) == "3mrrduxumfbzc"
    end

    test "raises on invalid clock ID" do
      assert_raise RuntimeError, fn ->
        TID.now(clock_id: 99_999)
      end
    end
  end

  describe "at_time/1" do
    test "generates a new TID" do
      assert TID.valid?(TID.at_time(DateTime.utc_now()))
    end

    test "can be made deterministic" do
      assert TID.at_time(~U[2026-07-29 08:00:00.00Z], 1000) == "3mrrhft7k22zc"
    end

    test "raises on invalid clock ID" do
      assert_raise FunctionClauseError, fn ->
        TID.at_time(DateTime.utc_now(), 99_999)
      end
    end
  end

  describe "new/1" do
    test "generates a new TID" do
      assert TID.valid?(TID.new(0))
    end

    test "raises on invalid input" do
      assert_raise FunctionClauseError, fn ->
        TID.new(-1)
      end
    end
  end

  describe "to_unix/1" do
    test "extracts the timestamp from a TID" do
      assert 1_788_529_851_404_467 == TID.to_unix("3mup4bbh67n2g")
      assert 1_788_529_851_376_468 == TID.to_unix("3mup4bbgcuo2c")
      assert 1_788_529_851_306_527 == TID.to_unix("3mup4bbe6kz2b")
    end

    test "extreme case" do
      assert 0 == TID.to_unix("2222222222222")
    end
  end

  describe "to_datetime/1" do
    test "extracts the datetime from a TID" do
      assert {:ok, ~U[2026-09-04 13:50:51.404467Z]} == TID.to_datetime("3mup4bbh67n2g")
      assert {:ok, ~U[2026-09-04 13:50:51.376468Z]} == TID.to_datetime("3mup4bbgcuo2c")
      assert {:ok, ~U[2026-09-04 13:50:51.306527Z]} == TID.to_datetime("3mup4bbe6kz2b")
    end

    test "roundtrips" do
      tid = TID.at_time(~U[2026-01-01 00:00:00.000000Z], 0)
      assert {:ok, ~U[2026-01-01 00:00:00.000000Z]} == TID.to_datetime(tid)

      tid = TID.at_time(~U[2026-01-01 00:00:00.000000Z], 1023)
      assert {:ok, ~U[2026-01-01 00:00:00.000000Z]} == TID.to_datetime(tid)
    end

    test "extreme case" do
      assert {:ok, ~U[1970-01-01 00:00:00.000000Z]} == TID.to_datetime("2222222222222")
    end
  end

  describe "to_datetime!/1" do
    test "unwraps the tuple" do
      assert ~U[2026-09-04 13:50:51.404467Z] == TID.to_datetime!("3mup4bbh67n2g")
    end
  end
end
