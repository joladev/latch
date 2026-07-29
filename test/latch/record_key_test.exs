defmodule Latch.RecordKeyTest do
  use ExUnit.Case, async: true

  alias Latch.RecordKey

  describe "valid?/1" do
    test "validates" do
      # Examples taken from https://atproto.com/specs/record-key#usage-and-implementation-guidelines
      assert RecordKey.valid?("3jui7kd54zh2y")
      assert RecordKey.valid?("self")
      assert RecordKey.valid?("example.com")
      assert RecordKey.valid?("~1.2-3_")
      assert RecordKey.valid?("dHJ1ZQ")
      assert RecordKey.valid?("pre:fix")
      assert RecordKey.valid?("_")

      refute RecordKey.valid?("alpha/beta")
      refute RecordKey.valid?(".")
      refute RecordKey.valid?("..")
      refute RecordKey.valid?("#extra")
      refute RecordKey.valid?("@handle")
      refute RecordKey.valid?("any space")
      refute RecordKey.valid?("any+space")
      refute RecordKey.valid?("number[3]")
      refute RecordKey.valid?("number(3)")
      refute RecordKey.valid?("\"quote\"")
      refute RecordKey.valid?("dHJ1ZQ==")
    end
  end
end
