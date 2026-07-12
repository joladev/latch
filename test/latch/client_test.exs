defmodule Latch.ClientTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.Client
  alias Latch.Config
  alias Latch.Discovery
  alias Latch.Error.XRPC, as: XRPCError
  alias Latch.Flow
  alias Latch.ServerMetadata
  alias Latch.Session
  alias Latch.XRPC

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"
  @pds "https://pds.example.com"
  @issuer "https://issuer.example.com"
  @client_id "https://client.example.com/oauth-client-metadata.json"
  @redirect_uri "https://client.example.com/oauth/callback"

  describe "query/3" do
    test "refreshes an expired session before making an XRPC query" do
      config = %Config{
        store: Latch.TestStore,
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        scope: "atproto",
        signing_key: nil
      }

      stale_session = session("stale-access-token", ~U[2020-01-01 00:00:00Z])
      refreshed_session = session("fresh-access-token", ~U[2030-01-01 00:00:00Z])
      server = server()

      :ok = Latch.TestStore.put_session(@did, stale_session)

      expect(Discovery, :discover, fn @pds -> {:ok, server} end)

      expect(Flow, :refresh, fn ^server, ^stale_session, opts ->
        assert opts[:client_id] == config.client_id
        assert opts[:client_jwk] == config.signing_key
        {:ok, refreshed_session}
      end)

      expect(XRPC, :query, fn ^refreshed_session, "app.bsky.actor.getProfile", actor: @did ->
        {:ok, %{"did" => @did}}
      end)

      assert {:ok, %{"did" => @did}} =
               Client.query(config, @did, "app.bsky.actor.getProfile", actor: @did)

      assert {:ok, ^refreshed_session} = Latch.TestStore.fetch_session(@did)
    end

    test "refreshes and retries once when an XRPC request returns 401" do
      config = %Config{
        store: Latch.TestStore,
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        scope: "atproto",
        signing_key: nil
      }

      stale_session = session("stale-access-token", ~U[2030-01-01 00:00:00Z])
      refreshed_session = session("fresh-access-token", ~U[2030-01-01 00:00:00Z])
      server = server()

      :ok = Latch.TestStore.put_session(@did, stale_session)

      expect(XRPC, :query, 2, fn
        ^stale_session, "app.bsky.actor.getProfile", actor: @did ->
          {:error, %XRPCError{status: 401, body: %{}}}

        ^refreshed_session, "app.bsky.actor.getProfile", actor: @did ->
          {:ok, %{"did" => @did}}
      end)

      expect(Discovery, :discover, fn @pds -> {:ok, server} end)

      expect(Flow, :refresh, fn ^server, ^stale_session, _opts ->
        {:ok, refreshed_session}
      end)

      assert {:ok, %{"did" => @did}} =
               Client.query(config, @did, "app.bsky.actor.getProfile", actor: @did)

      assert {:ok, ^refreshed_session} = Latch.TestStore.fetch_session(@did)
    end
  end

  defp session(access_token, expires_at) do
    %Session{
      did: @did,
      access_token: access_token,
      refresh_token: "refresh-token",
      dpop_key: nil,
      scope: "atproto",
      issuer: @issuer,
      pds_endpoint: @pds,
      expires_at: expires_at
    }
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
end
