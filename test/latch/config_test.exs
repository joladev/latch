defmodule Latch.ConfigTest do
  use ExUnit.Case, async: true

  alias Latch.Config

  @store Latch.TestStore
  @client_id "client_id"
  @redirect_uri "redirect_uri"
  @scope "atproto something"
  @signing_key "signing_key"
  @name :name
  @client_name "client_name"
  @client_uri "client_uri"

  describe "build!/1" do
    test "happy path" do
      assert %Config{} = config = Config.build!(opts([]))

      assert config.store == @store
      assert config.client_id == @client_id
      assert config.redirect_uri == @redirect_uri
      assert config.scope == @scope
      assert config.signing_key == @signing_key
      assert config.name == @name
      assert config.client_name == @client_name
      assert config.client_uri == @client_uri

      # Verify that the default is populated
      assert config.request_ttl
    end

    test "fails on invalid" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.build!(opts(store: "string"))
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Config.build!(opts(doesntexist: "string"))
      end
    end
  end

  defp opts(overrides) do
    Keyword.merge(
      [
        store: @store,
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        scope: @scope,
        signing_key: @signing_key,
        name: @name,
        client_name: @client_name,
        client_uri: @client_uri
      ],
      overrides
    )
  end
end
