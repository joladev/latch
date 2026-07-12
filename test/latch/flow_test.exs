defmodule Latch.FlowTest do
  use ExUnit.Case, async: true
  use Mimic

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

      client_jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      dpop_key = JOSE.JWK.generate_key({:ec, "P-256"})

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
               Flow.exchange_code(
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
      client_jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      dpop_key = JOSE.JWK.generate_key({:ec, "P-256"})

      server = %ServerMetadata{
        issuer: "https://issuer.example.com",
        authorization_endpoint: "https://issuer.example.com/oauth/authorize",
        token_endpoint: "https://issuer.example.com/oauth/token",
        par_endpoint: "https://issuer.example.com/oauth/par",
        scopes_supported: ["atproto"]
      }

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
               Flow.par(server,
                 client_id: "https://client.example.com/oauth-client-metadata.json",
                 client_jwk: client_jwk,
                 redirect_uri: "https://client.example.com/oauth/callback",
                 scope: "atproto",
                 state: "state",
                 code_challenge: "pkce-challenge",
                 dpop_key: dpop_key,
                 login_hint: "alice.example.com"
               )
    end
  end

  describe "refresh/3" do
    test "rejects a refresh when discovery returns a different issuer" do
      reject(HTTP, :post_form, 3)

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
               Flow.refresh(server, session, client_id: "client-id", client_jwk: nil)
    end
  end
end
