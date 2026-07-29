defmodule Latch.DPoPTest do
  use ExUnit.Case, async: true

  alias Latch.Config
  alias Latch.DPoP
  alias Latch.NonceCache

  describe "with_nonce/4" do
    test "retry with nonce after challenge" do
      config = %Config{
        store: Latch.TestStore,
        client_id: "client_id",
        redirect_uri: "direct_uri",
        scope: "atproto",
        signing_key: nil,
        name: :"#{inspect(self())}",
        mode: :confidential
      }

      start_link_supervised!(
        {NonceCache, name: config.name, config: config, sweep_disabled: true}
      )

      dpop_key = DPoP.generate_key()
      url = "https://example.com"
      expected_nonce = "expected"
      expected_response = {:ok, "body"}
      expected_result = {expected_response, expected_nonce}

      assert ^expected_response =
               DPoP.with_nonce(config, dpop_key, url, fn
                 nil ->
                   send(self(), :nil_case)
                   {:challenge, expected_nonce}

                 ^expected_nonce ->
                   send(self(), :nonce_case)
                   expected_result
               end)

      assert_receive :nil_case
      assert_receive :nonce_case

      thumbprint = DPoP.thumbprint(dpop_key)
      assert {:ok, ^expected_nonce} = NonceCache.get_nonce(config, thumbprint, url)
    end

    test "uses cached nonce" do
      config = %Config{
        store: Latch.TestStore,
        client_id: "client_id",
        redirect_uri: "direct_uri",
        scope: "atproto",
        signing_key: nil,
        name: :"#{inspect(self())}",
        mode: :confidential
      }

      start_link_supervised!(
        {NonceCache, name: config.name, config: config, sweep_disabled: true}
      )

      dpop_key = DPoP.generate_key()
      url = "https://example.com"
      expected_nonce = "expected"
      expected_response = {:ok, "body"}
      expected_result = {expected_response, expected_nonce}
      thumbprint = DPoP.thumbprint(dpop_key)

      NonceCache.put_nonce(config, thumbprint, url, expected_nonce)

      assert ^expected_response =
               DPoP.with_nonce(config, dpop_key, url, fn
                 ^expected_nonce ->
                   send(self(), :nonce_case)
                   expected_result
               end)

      assert_receive :nonce_case
    end
  end
end
