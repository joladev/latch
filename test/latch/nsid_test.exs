defmodule Latch.NSIDTest do
  use ExUnit.Case, async: true

  alias Latch.NSID

  describe "valid?/1" do
    test "validates" do
      assert NSID.valid?("com.example.fooBar")
      assert NSID.valid?("net.users.bob.ping")
      assert NSID.valid?("a-0.b-1.c")
      assert NSID.valid?("a.b.c")
      assert NSID.valid?("com.example.fooBarV2")
      assert NSID.valid?("cn.8.lex.stuff")

      refute NSID.valid?("com.exa💩ple.thing")
      refute NSID.valid?("com.example")
      refute NSID.valid?("com.example.3")
    end
  end

  describe "name/1" do
    test "grabs name" do
      assert NSID.name("site.standard.document") == "document"
    end
  end

  describe "authority/1" do
    test "grabs authority" do
      assert NSID.authority("site.standard.document") == "site.standard"
    end
  end
end
