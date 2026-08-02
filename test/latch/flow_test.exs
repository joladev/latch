defmodule Latch.FlowTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.DPoP
  alias Latch.Error.SecurityViolation
  alias Latch.Flow
  alias Latch.HTTP
  alias Latch.ServerMetadata
  alias Latch.Session

  describe "exchange_code/1" do
    test "exchanges an authorization code for a session" do
      did = "did:plc:bvraa6gajy4tfr3eh2sisdkr"
      access_token = "access-token"
      refresh_token = "refresh-token"
      config = make_config()

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      client_jwk = DPoP.generate_key()
      dpop_key = DPoP.generate_key()

      expect(HTTP, :post_form, fn url, form, headers ->
        assert url == "https://issuer.example.com/oauth/token"
        assert form[:grant_type] == "authorization_code"
        assert form[:code] == "authorization-code"
        assert form[:code_verifier] == "pkce-verifier"
        assert is_binary(form[:client_assertion])
        assert {"dpop", proof} = List.keyfind(headers, "dpop", 0)
        assert is_binary(proof)

        {:ok,
         %{
           status: 200,
           headers: %{},
           body:
             Jason.encode!(%{
               "access_token" => access_token,
               "refresh_token" => refresh_token,
               "token_type" => "DPoP",
               "expires_in" => 3600,
               "scope" => "atproto",
               "sub" => did
             })
         }}
      end)

      assert {:ok, session} =
               Flow.exchange_code(config,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 client_jwk: client_jwk,
                 redirect_uri: "https://client.example.com/oauth/callback",
                 code: "authorization-code",
                 code_verifier: "pkce-verifier",
                 dpop_key: dpop_key,
                 expected_did: did,
                 pds_endpoint: "https://pds.example.com",
                 issuer: "https://issuer.example.com",
                 token_endpoint: "https://issuer.example.com/oauth/token",
                 now: ~U[2026-01-01 00:00:00Z]
               )

      assert session.did == did
      assert session.access_token == access_token
      assert session.refresh_token == refresh_token
      assert session.dpop_key == dpop_key
      assert session.expires_at == ~U[2026-01-01 01:00:00Z]
    end
  end

  describe "par/2" do
    test "creates a pushed authorization request" do
      dpop_key = DPoP.generate_key()
      config = make_config()

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      server = make_server_metadata()

      expect(HTTP, :post_form, fn url, form, headers ->
        assert url == "https://issuer.example.com/oauth/par"
        assert form[:response_type] == "code"
        assert form[:state] == "state"
        assert form[:code_challenge] == "pkce-challenge"
        assert {"dpop", proof} = List.keyfind(headers, "dpop", 0)
        assert is_binary(proof)

        {:ok,
         %{
           status: 201,
           headers: %{},
           body: ~s({"request_uri":"urn:ietf:params:oauth:request_uri:request"})
         }}
      end)

      assert {:ok, "urn:ietf:params:oauth:request_uri:request"} =
               Flow.par(config, server,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 redirect_uri: "https://client.example.com/oauth/callback",
                 scope: "atproto",
                 state: "state",
                 code_challenge: "pkce-challenge",
                 dpop_key: dpop_key,
                 login_hint: "alice.example.com"
               )
    end

    test "retries with nonce" do
      dpop_key = DPoP.generate_key()
      config = make_config()
      expected_nonce = "expected"

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      server = make_server_metadata()

      expect(HTTP, :post_form, fn _url, _form, headers ->
        assert [{"dpop", proof}] = headers
        [_header, payload, _signature] = String.split(proof, ".")

        decoded_payload =
          payload
          |> Base.url_decode64!(padding: false)
          |> Jason.decode!()

        # There is no nonce because the AS has not given us one yet.
        refute decoded_payload["nonce"]
        assert decoded_payload["htm"] == "POST"
        assert decoded_payload["htu"] == server.par_endpoint

        send(self(), {:jti, decoded_payload["jti"]})

        {:ok,
         %{
           status: 400,
           headers: %{"dpop-nonce" => [expected_nonce]},
           body: Jason.encode!(%{error: "use_dpop_nonce"})
         }}
      end)

      expect(HTTP, :post_form, fn _url, _form, headers ->
        assert [{"dpop", proof}] = headers
        [_header, payload, _signature] = String.split(proof, ".")

        decoded_payload =
          payload
          |> Base.url_decode64!(padding: false)
          |> Jason.decode!()

        assert_receive {:jti, jti}

        assert expected_nonce == decoded_payload["nonce"]

        # `jti` must be unique per request
        refute jti == decoded_payload["jti"]

        {:ok,
         %{
           status: 201,
           headers: %{},
           body: ~s({"request_uri":"urn:ietf:params:oauth:request_uri:request"})
         }}
      end)

      assert {:ok, "urn:ietf:params:oauth:request_uri:request"} =
               Flow.par(config, server,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 redirect_uri: "https://client.example.com/oauth/callback",
                 scope: "atproto",
                 state: "state",
                 code_challenge: "pkce-challenge",
                 dpop_key: dpop_key,
                 login_hint: "alice.example.com"
               )
    end

    test "public client omits client_assertion" do
      dpop_key = DPoP.generate_key()
      config = make_config(mode: :public)

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      server = make_server_metadata()

      expect(HTTP, :post_form, fn url, form, _headers ->
        assert url == server.par_endpoint
        refute Keyword.has_key?(form, :client_assertion)
        refute Keyword.has_key?(form, :client_assertion_type)

        {:ok,
         %{
           status: 201,
           headers: %{},
           body: ~s({"request_uri":"urn:ietf:params:oauth:request_uri:request"})
         }}
      end)

      assert {:ok, "urn:ietf:params:oauth:request_uri:request"} =
               Flow.par(config, server,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 redirect_uri: "https://client.example.com/oauth/callback",
                 scope: "atproto",
                 state: "state",
                 code_challenge: "pkce-challenge",
                 dpop_key: dpop_key
               )
    end

    test "localhost client omits client_assertion" do
      dpop_key = DPoP.generate_key()

      config =
        make_config(mode: :localhost)

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      server = make_server_metadata()

      expect(HTTP, :post_form, fn url, form, _headers ->
        assert url == server.par_endpoint
        refute Keyword.has_key?(form, :client_assertion)
        refute Keyword.has_key?(form, :client_assertion_type)

        {:ok,
         %{
           status: 201,
           headers: %{},
           body: ~s({"request_uri":"urn:ietf:params:oauth:request_uri:request"})
         }}
      end)

      assert {:ok, "urn:ietf:params:oauth:request_uri:request"} =
               Flow.par(config, server,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 redirect_uri: "https://client.example.com/oauth/callback",
                 scope: "atproto",
                 state: "state",
                 code_challenge: "pkce-challenge",
                 dpop_key: dpop_key
               )
    end
  end

  describe "refresh/3" do
    test "rejects a refresh when discovery returns a different issuer" do
      reject(HTTP, :post_form, 3)
      config = make_config()

      start_link_supervised!(
        {Latch.NonceCache, config: config, name: config.name, sweep_disabled: true}
      )

      server = %ServerMetadata{
        issuer: "https://other.example.com",
        authorization_endpoint: "https://other.example.com/oauth/authorize",
        token_endpoint: "https://other.example.com/oauth/token",
        par_endpoint: "https://other.example.com/oauth/par",
        scopes_supported: ["atproto"]
      }

      session = %Session{
        did: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: nil,
        scope: "atproto",
        issuer: "https://issuer.example.com",
        pds_endpoint: "https://pds.example.com",
        expires_at: ~U[2026-01-01 00:00:00Z]
      }

      assert {:error, %SecurityViolation{reason: :issuer_mismatch}} =
               Flow.refresh(config, server, session,
                 client_id: "client-id",
                 client_jwk: nil
               )
    end
  end

  defp make_config(overrides \\ []) do
    defaults = [
      store: Latch.TestStore,
      client_id_path: "/oauth-client-metadata.json",
      redirect_uri_path: "/oauth/callback",
      scope: "atproto",
      signing_key: Jason.decode!(Jason.encode!(Latch.DPoP.generate_key())),
      name: :"flow_test_#{inspect(self())}",
      mode: :confidential,
      base_url_fun: fn -> "https://client.example.com" end
    ]

    attrs = Keyword.merge(defaults, overrides)
    struct!(Latch.Config, attrs)
  end

  defp make_server_metadata do
    %ServerMetadata{
      issuer: "https://issuer.example.com",
      authorization_endpoint: "https://issuer.example.com/oauth/authorize",
      token_endpoint: "https://issuer.example.com/oauth/token",
      par_endpoint: "https://issuer.example.com/oauth/par",
      scopes_supported: ["atproto"]
    }
  end
end
