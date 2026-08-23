defmodule Latch.ConfigTest do
  use ExUnit.Case, async: true

  alias Latch.Config

  @store Latch.TestStore
  @client_id_path "/client_id"
  @client_id "https://client.example.com" <> @client_id_path
  @redirect_uri_path "/redirect_uri"
  @redirect_uri "https://client.example.com" <> @redirect_uri_path
  @scope "atproto something"
  @signing_key ~s({"kty":"EC"})
  @name :name
  @client_name "client_name"
  @client_uri "client_uri"

  describe "build!/1" do
    test "happy path" do
      assert %Config{} = config = Config.build!(opts([]))

      assert config.store == @store
      assert Config.client_id(config) == @client_id
      assert Config.redirect_uri(config) == @redirect_uri
      assert config.scope == @scope
      assert config.signing_key == Jason.decode!(@signing_key)
      assert config.name == @name
      assert config.client_name == @client_name
      assert config.client_uri == @client_uri
    end

    test "fails on invalid" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.build!(opts(store: "string"))
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Config.build!(opts(doesntexist: "string"))
      end
    end

    test "localhost mode rejects :client_id" do
      assert_raise NimbleOptions.ValidationError,
                   fn ->
                     [mode: :localhost, client_id: "https://prod.example/metadata.json"]
                     |> opts()
                     |> Keyword.delete(:signing_key)
                     |> Config.build!()
                   end
    end

    test "confidential mode requires :signing_key" do
      assert_raise NimbleOptions.ValidationError,
                   fn ->
                     opts()
                     |> Keyword.delete(:signing_key)
                     |> Config.build!()
                   end
    end

    test "public mode rejects :signing_key" do
      assert_raise NimbleOptions.ValidationError,
                   fn ->
                     [mode: :public]
                     |> opts()
                     |> Config.build!()
                   end
    end

    test "localhost mode rejects :signing_key" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/invalid value for :signing_key option, not allowed when mode is :localhost/,
                   fn ->
                     [mode: :localhost]
                     |> opts()
                     |> Keyword.delete(:client_id_path)
                     |> Config.build!()
                   end
    end
  end

  defp opts(overrides \\ []) do
    Keyword.merge(
      [
        store: @store,
        client_id_path: @client_id_path,
        redirect_uri_path: @redirect_uri_path,
        scope: @scope,
        signing_key: @signing_key,
        name: @name,
        client_name: @client_name,
        client_uri: @client_uri,
        mode: :confidential,
        base_url_fun: fn -> "https://client.example.com" end
      ],
      overrides
    )
  end
end
