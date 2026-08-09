defmodule Latch.Store.ETSTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.Discovery
  alias Latch.DPoP
  alias Latch.Flow
  alias Latch.Identity
  alias Latch.ServerMetadata
  alias Latch.Session
  alias Latch.XRPC

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"
  @handle "jola.dev"
  @client_id_path "/oauth-client-metadata.json"
  @redirect_uri_path "/oauth/callback"
  @issuer "https://issuer.example.com"
  @pds "https://pds.example.com"
  @dpop_key DPoP.generate_key()

  describe "integration test suite" do
    test "lifecycle" do
      pid = start_latch()

      # AUTHORIZE SECTION

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      expect(Identity, :resolve_handle, fn _config, _handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :par, fn _config, _server, opts ->
        send(self(), {:state, opts[:state]})
        {:ok, request_uri}
      end)

      {:ok, _redirect_url} = Latch.authorize(pid, @handle)

      assert_receive {:state, state}

      # CALLBACK SECTION

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: @dpop_key,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
      }

      expect(Flow, :exchange_code, fn _config, _opts ->
        {:ok, session}
      end)

      assert {:ok, %{did: @did, handle: @handle}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )

      # CLIENT SECTION

      expect(XRPC, :query, fn _config, _session, _method, _opts ->
        {:ok, %{"did" => @did}}
      end)

      assert {:ok, %{"did" => @did}} =
               Latch.query(pid, @did, "app.bsky.actor.getProfile", actor: @did)

      assert :ok = Latch.delete_session(pid, @did)

      reject(&XRPC.query/4)

      assert {:error, %Latch.Error.NoSession{}} =
               Latch.query(pid, @did, "app.bsky.actor.getProfile", actor: @did)
    end

    test "callback is single use" do
      pid = start_latch()

      # AUTHORIZE SECTION

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      expect(Identity, :resolve_handle, fn _config, _handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :par, fn _config, _server, opts ->
        send(self(), {:state, opts[:state]})
        {:ok, request_uri}
      end)

      {:ok, _redirect_url} = Latch.authorize(pid, @handle)

      assert_receive {:state, state}

      # CALLBACK SECTION

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: @dpop_key,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
      }

      expect(Flow, :exchange_code, fn _config, _opts ->
        {:ok, session}
      end)

      assert {:ok, %{did: @did, handle: @handle}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )

      assert {:error, %Latch.Error.SecurityViolation{}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )
    end

    test "expired request" do
      pid = start_latch(request_ttl: 0)

      # AUTHORIZE SECTION

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      expect(Identity, :resolve_handle, fn _config, _handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :par, fn _config, _server, opts ->
        send(self(), {:state, opts[:state]})
        {:ok, request_uri}
      end)

      {:ok, _redirect_url} = Latch.authorize(pid, @handle)

      assert_receive {:state, state}

      assert {:error, %Latch.Error.SecurityViolation{reason: :state_mismatch}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )
    end

    test "refresh token" do
      pid = start_latch()

      # AUTHORIZE SECTION

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      expect(Identity, :resolve_handle, fn _config, _handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :par, fn _config, _server, opts ->
        send(self(), {:state, opts[:state]})
        {:ok, request_uri}
      end)

      {:ok, _redirect_url} = Latch.authorize(pid, @handle)

      assert_receive {:state, state}

      # CALLBACK SECTION

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: @dpop_key,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: DateTime.utc_now(:second)
      }

      expect(Flow, :exchange_code, fn _config, _opts ->
        {:ok, session}
      end)

      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :refresh, fn _config, _server, old_session, _opts ->
        assert session == old_session

        {:ok,
         %Session{
           did: @did,
           access_token: "access-token",
           refresh_token: "refresh-token",
           dpop_key: @dpop_key,
           scope: "atproto",
           issuer: @issuer,
           pds_endpoint: @pds,
           expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
         }}
      end)

      assert {:ok, %{did: @did}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )

      expect(XRPC, :query, fn _config, _session, _method, _opts ->
        {:ok, %{"did" => @did}}
      end)

      assert {:ok, %{"did" => @did}} =
               Latch.query(pid, @did, "app.bsky.actor.getProfile", actor: @did)
    end

    test "refresh storm" do
      pid = start_latch()

      # AUTHORIZE SECTION

      identity = %Identity{did: @did, handle: @handle, pds_endpoint: @pds}
      server = server()
      request_uri = "urn:ietf:params:oauth:request_uri:request"

      expect(Identity, :resolve_handle, fn _config, _handle -> {:ok, identity} end)
      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      expect(Flow, :par, fn _config, _server, opts ->
        send(self(), {:state, opts[:state]})
        {:ok, request_uri}
      end)

      {:ok, _redirect_url} = Latch.authorize(pid, @handle)

      assert_receive {:state, state}

      # CALLBACK SECTION

      session = %Session{
        did: @did,
        access_token: "access-token",
        refresh_token: "refresh-token",
        dpop_key: @dpop_key,
        scope: "atproto",
        issuer: @issuer,
        pds_endpoint: @pds,
        expires_at: DateTime.utc_now(:second)
      }

      expect(Flow, :exchange_code, fn _config, _opts ->
        {:ok, session}
      end)

      expect(Discovery, :discover, fn _config, _pds, _opts -> {:ok, server} end)

      # Refresh only happens once even when we trigger refresh 10 times
      # by using XPRC in a `for` below.
      expect(Flow, :refresh, fn _config, _server, old_session, _opts ->
        assert session == old_session

        {:ok,
         %Session{
           did: @did,
           access_token: "access-token-2",
           refresh_token: "refresh-token",
           dpop_key: @dpop_key,
           scope: "atproto",
           issuer: @issuer,
           pds_endpoint: @pds,
           expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
         }}
      end)

      assert {:ok, %{did: @did}} =
               Latch.callback(
                 pid,
                 %{
                   "state" => state,
                   "iss" => @issuer,
                   "code" => "auth-code"
                 }
               )

      expect(XRPC, :query, 10, fn _config, _session, _method, _opts ->
        {:ok, %{"did" => @did}}
      end)

      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            assert {:ok, %{"did" => @did}} =
                     Latch.query(pid, @did, "app.bsky.actor.getProfile", actor: @did)
          end)
        end

      Task.await_many(tasks)
    end
  end

  defp start_latch(overrides \\ []) do
    name = String.to_atom("latch_#{inspect(self())}")
    store_pid = start_link_supervised!({Latch.ETSStore, []})
    Mimic.allow(Latch.Flow, self(), store_pid)
    Mimic.allow(Latch.Discovery, self(), store_pid)

    opts =
      Keyword.merge(
        [
          name: name,
          store: Latch.ETSStore,
          client_id_path: @client_id_path,
          redirect_uri_path: @redirect_uri_path,
          scope: "atproto",
          signing_key: Jason.encode!(@dpop_key),
          mode: :confidential,
          base_url_fun: fn -> "https://client.example.com" end
        ],
        overrides
      )

    start_link_supervised!({Latch, opts})
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
