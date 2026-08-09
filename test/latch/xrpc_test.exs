defmodule Latch.XRPCTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.Config
  alias Latch.DPoP
  alias Latch.HTTP
  alias Latch.Session
  alias Latch.XRPC

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"

  describe "query/4" do
    test "passes all relevant information to HTTP call" do
      config = make_config()
      session = make_session()
      method = "app.bsky.actor.getProfile"
      params = [actor: @did]
      service = "did:web:api.bsky.app#bsky_appview"

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      expect(HTTP, :request, fn _pool, http_method, url, headers, body, _opts ->
        assert http_method == "GET"
        assert url == "#{session.pds_endpoint}/xrpc/#{method}?#{URI.encode_query(params)}"
        assert {"atproto-proxy", service} in headers
        assert {"authorization", "DPoP access-token"} in headers
        assert {"dpop", _} = List.keyfind(headers, "dpop", 0)

        assert body == nil

        {:ok, %{status: 200, body: ~s|{"did": "string"}|, headers: %{}}}
      end)

      assert {:ok, %{"did" => "string"}} =
               XRPC.query(config, session, method,
                 params: params,
                 service: service
               )
    end

    test "handles no params case" do
      config = make_config()
      session = make_session()
      method = "com.atproto.server.getSession"

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      expect(HTTP, :request, fn _pool, http_method, url, headers, body, _opts ->
        assert http_method == "GET"
        assert url == "#{session.pds_endpoint}/xrpc/#{method}"
        assert {"authorization", "DPoP access-token"} in headers
        assert {"dpop", _} = List.keyfind(headers, "dpop", 0)

        assert body == nil

        {:ok, %{status: 200, body: ~s|{"did": "string"}|, headers: %{}}}
      end)

      assert {:ok, %{"did" => "string"}} = XRPC.query(config, session, method, [])
    end

    test "passes http opts through" do
      config = make_config()
      session = make_session()
      method = "com.atproto.server.getSession"

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      expect(HTTP, :request, fn _pool, http_method, url, headers, body, opts ->
        assert Keyword.fetch!(opts, :receive_timeout) == 30_000
        assert http_method == "GET"
        assert url == "#{session.pds_endpoint}/xrpc/#{method}"
        assert {"authorization", "DPoP access-token"} in headers
        assert {"dpop", _} = List.keyfind(headers, "dpop", 0)

        assert body == nil

        {:ok, %{status: 200, body: ~s|{"did": "string"}|, headers: %{}}}
      end)

      assert {:ok, %{"did" => "string"}} =
               XRPC.query(config, session, method, http: [receive_timeout: 30_000])
    end
  end

  describe "procedure/5" do
    test "passes all relevant information to HTTP call" do
      config = make_config()
      session = make_session()
      method = "app.bsky.actor.getProfile"
      service = "did:web:api.bsky.app#bsky_appview"
      expected_body = ~s|{"x": "y"}|

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      expect(HTTP, :request, fn _pool, http_method, url, headers, body, _opts ->
        assert http_method == "POST"
        assert url == "#{session.pds_endpoint}/xrpc/#{method}"
        assert {"atproto-proxy", service} in headers
        assert {"authorization", "DPoP access-token"} in headers
        assert {"dpop", _} = List.keyfind(headers, "dpop", 0)

        assert {:json, expected_body} == body

        {:ok, %{status: 200, body: ~s|{"did": "string"}|, headers: %{}}}
      end)

      assert {:ok, %{"did" => "string"}} =
               XRPC.procedure(config, session, method, expected_body, service: service)
    end
  end

  describe "upload_blob/5" do
    test "passes all relevant information to HTTP call" do
      config = make_config()
      session = make_session()
      method = "com.atproto.repo.uploadBlob"
      service = "did:web:api.bsky.app#bsky_appview"
      expected_body = "bytes"

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      expect(HTTP, :request, fn _pool, http_method, url, headers, body, _opts ->
        assert http_method == "POST"
        assert url == "#{session.pds_endpoint}/xrpc/#{method}"
        assert {"atproto-proxy", service} in headers
        assert {"authorization", "DPoP access-token"} in headers
        assert {"dpop", _} = List.keyfind(headers, "dpop", 0)

        assert {:raw, expected_body, "image/png"} == body

        {:ok, %{status: 200, body: ~s|{"did": "string"}|, headers: %{}}}
      end)

      assert {:ok, %{"did" => "string"}} =
               XRPC.upload_blob(config, session, expected_body, "image/png", service: service)
    end
  end

  defp make_config(overrides \\ []) do
    defaults = [
      store: Latch.TestStore,
      client_id_path: "/oauth-client-metadata.json",
      redirect_uri_path: "/oauth/callback",
      scope: "atproto",
      signing_key: Jason.decode!(Jason.encode!(DPoP.generate_key())),
      name: :"flow_test_#{inspect(self())}",
      mode: :confidential,
      base_url_fun: fn -> "https://client.example.com" end
    ]

    attrs = Keyword.merge(defaults, overrides)
    struct!(Config, attrs)
  end

  defp make_session(overrides \\ []) do
    defaults = [
      did: @did,
      access_token: "access-token",
      refresh_token: "refresh-token",
      dpop_key: DPoP.generate_key(),
      scope: "atproto",
      issuer: "https://issuer.example.com",
      pds_endpoint: "https://pds.example.com",
      expires_at: ~U[2026-01-01 00:00:00Z]
    ]

    attrs = Keyword.merge(defaults, overrides)
    struct!(Session, attrs)
  end
end
