defmodule LatchTest do
  use ExUnit.Case, async: true
  use Mimic
  doctest Latch

  alias Latch.Discovery
  alias Latch.Flow
  alias Latch.Identity
  alias Latch.Request
  alias Latch.ServerMetadata
  alias Latch.Session

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"
  @handle "alice.example.com"
  @pds "https://pds.example.com"
  @issuer "https://issuer.example.com"
  @client_id "https://client.example.com/oauth-client-metadata.json"
  @redirect_uri "https://client.example.com/oauth/callback"

  describe "authorize/2" do
    test "resolves identity, creates PAR, stores the request, and returns the redirect URL" do
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      pid =
        start_latch(
          store: Latch.TestStore,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          scope: "atproto",
          signing_key: nil
        )

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()

      expect(Identity, :resolve_handle, fn @handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn @pds -> {:ok, server} end)

      expect(Flow, :par, fn config, ^server, opts ->
        assert opts[:client_id] == config.client_id
        assert opts[:redirect_uri] == config.redirect_uri
        assert opts[:scope] == config.scope
        assert opts[:login_hint] == @handle
        assert is_binary(opts[:state])
        assert is_binary(opts[:code_challenge])
        assert %JOSE.JWK{} = opts[:dpop_key]

        {:ok, request_uri}
      end)

      assert {:ok, redirect_url} = Latch.authorize(pid, @handle)

      assert URI.parse(redirect_url).path == "/oauth/authorize"

      query =
        redirect_url
        |> URI.parse()
        |> Map.fetch!(:query)
        |> URI.decode_query()

      assert %{
               "client_id" => @client_id,
               "request_uri" => ^request_uri
             } = query

      assert_receive {:request_stored, state, %Request{} = request, 600}
      assert request.state == state
      assert request.did == @did
      assert request.handle == @handle
      assert request.pds_endpoint == @pds
      assert request.issuer == @issuer
      assert request.token_endpoint == @issuer <> "/oauth/token"
      assert is_binary(request.pkce_verifier)
      assert %JOSE.JWK{} = request.dpop_key
    end
  end

  describe "callback/2" do
    test "consumes the request, verifies the issuer, and exchanges the authorization code" do
      state = "state-123"
      code = "authorization-code"
      dpop_key = JOSE.JWK.generate_key({:ec, "P-256"})

      pid =
        start_latch(
          store: Latch.TestStore,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          scope: "atproto",
          signing_key: nil
        )

      request = %Request{
        state: state,
        did: @did,
        handle: @handle,
        pds_endpoint: @pds,
        issuer: @issuer,
        token_endpoint: @issuer <> "/oauth/token",
        pkce_verifier: "pkce-verifier",
        dpop_key: dpop_key
      }

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: dpop_key,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: ~U[2026-01-01 01:00:00Z]
      }

      :ok = Latch.TestStore.put_request(state, request, 600)

      expect(Flow, :exchange_code, fn _config, opts ->
        assert opts[:code] == code
        assert opts[:code_verifier] == "pkce-verifier"
        assert opts[:dpop_key] == dpop_key
        assert opts[:expected_did] == @did
        assert opts[:issuer] == @issuer
        assert opts[:token_endpoint] == @issuer <> "/oauth/token"

        {:ok, session}
      end)

      assert {:ok, ^session} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => code
                 }
               )

      assert {:error, %Latch.Error.SecurityViolation{reason: :state_mismatch}} =
               Latch.callback(pid, %{"state" => state, "iss" => @issuer, "code" => code})
    end
  end

  describe "refresh/2" do
    test "rediscovers the authorization server and refreshes the session" do
      pid =
        start_latch(
          store: Latch.TestStore,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          scope: "atproto",
          signing_key: nil
        )

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: nil,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: ~U[2026-01-01 00:00:00Z]
      }

      refreshed_session = %{session | access_token: "refreshed-access-token"}
      server = server()

      expect(Discovery, :discover, fn @pds -> {:ok, server} end)

      expect(Flow, :refresh, fn config, ^server, ^session, opts ->
        assert opts[:client_id] == config.client_id
        assert opts[:client_jwk] == nil
        {:ok, refreshed_session}
      end)

      assert {:ok, ^refreshed_session} = Latch.refresh(pid, session)
    end
  end

  defp server do
    %ServerMetadata{
      issuer: @issuer,
      authorization_endpoint: @issuer <> "/oauth/authorize",
      token_endpoint: @issuer <> "/oauth/token",
      par_endpoint: @issuer <> "/oauth/par",
      scopes_supported: ["atproto"]
    }
  end

  defp start_latch(opts) do
    name = String.to_atom("latch_#{inspect(self())}")
    opts = Keyword.put(opts, :name, name)
    start_link_supervised!({Latch, opts})
  end
end
