defmodule Latch.NonceCacheTest do
  use ExUnit.Case, async: true

  alias Latch.Config
  alias Latch.NonceCache

  describe "get_nonce/3" do
    test "returns error if no nonce exists" do
      name = :"nonce_test_#{inspect(self())}"
      config = config(name)
      session_id = "1"
      origin = "example.com"

      _pid =
        start_link_supervised!({NonceCache, config: config, name: name, sweep_disabled: true})

      assert :error = NonceCache.get_nonce(config, session_id, origin)
    end
  end

  describe "put_nonce/3" do
    test "returns nonce if exists" do
      name = :"nonce_test_#{inspect(self())}"
      config = config(name)
      session_id = "1"
      origin = "example.com"
      nonce = "nonce"

      _pid =
        start_link_supervised!({NonceCache, config: config, name: name, sweep_disabled: true})

      # Empty cache, return error
      assert :error = NonceCache.get_nonce(config, session_id, origin)

      # Store in cache
      assert :ok = NonceCache.put_nonce(config, session_id, origin, nonce)

      # Returns now
      assert {:ok, ^nonce} = NonceCache.get_nonce(config, session_id, origin)

      # Other things don't exist
      assert :error = NonceCache.get_nonce(config, "other", origin)
      assert :error = NonceCache.get_nonce(config, session_id, "other")
    end
  end

  describe "GenServer" do
    test "sweeps old records" do
      name = :"nonce_test_#{inspect(self())}"
      config = config(name)
      session_id = "1"
      origin = "example.com"
      nonce = "nonce"

      pid =
        start_link_supervised!(
          {NonceCache, config: config, name: name, sweep_after: 0, sweep_disabled: true}
        )

      assert NonceCache.row_count(config) == 0

      # Set negative TTL to force sweep
      ttl_ms = -1

      # Store in cache
      assert :ok = NonceCache.put_nonce(config, session_id, origin, nonce, ttl_ms)

      assert NonceCache.row_count(config) == 1

      send(pid, :sweep)
      :sys.get_state(pid)

      assert NonceCache.row_count(config) == 0
    end
  end

  defp config(name) do
    %Config{
      store: Latch.TestStore,
      client_id: "client-id",
      redirect_uri: "redirect-uri",
      scope: "atproto",
      signing_key: nil,
      name: name
    }
  end
end
