defmodule Latch.Client do
  @moduledoc """
  Authenticated XRPC for a logged in did, with transparent token refresh.

  Loads the session from config, ensuring the access token is current,
  and delegates to `Latch.XRPC`. Refresh-token rotation is single-use and
  serialized through `Store.update_session/2`.
  """

  alias Latch.Config
  alias Latch.Discovery
  alias Latch.Error
  alias Latch.Error.NoSession
  alias Latch.Error.RefreshFailed
  alias Latch.Error.Store, as: StoreError
  alias Latch.Error.XRPC, as: XRPCError
  alias Latch.Flow
  alias Latch.XRPC

  @refresh_buffer_seconds 60

  @doc """
  Performs an authenticated XRPC query for `did`, with automatic refresh.
  """
  @spec query(Config.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def query(%Config{} = config, did, method, params \\ []) do
    call(config, did, fn session -> XRPC.query(session, method, params) end)
  end

  @doc """
  Performs an authenticated XRPC procedure for `did`, with automatic refresh.
  """
  @spec procedure(Config.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def procedure(%Config{} = config, did, method, body) do
    call(config, did, fn session -> XRPC.procedure(session, method, body) end)
  end

  @doc """
  Uploads a blob for `did`, with automatic refresh.
  """
  @spec upload_blob(Config.t(), String.t(), binary(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def upload_blob(%Config{} = config, did, bytes, content_type) do
    call(config, did, fn session -> XRPC.upload_blob(session, bytes, content_type) end)
  end

  defp call(config, did, fun) do
    with {:ok, session} <- fresh_session(config, did) do
      with {:error, %XRPCError{status: 401}} <- fun.(session),
           {:ok, refreshed} <- refresh(config, did, session.access_token) do
        fun.(refreshed)
      end
    end
  end

  defp fresh_session(config, did) do
    case config.store.fetch_session(did) do
      {:ok, session} ->
        if expired?(session) do
          refresh(config, did, session.access_token)
        else
          {:ok, session}
        end

      {:error, :not_found} ->
        {:error, %NoSession{did: did}}

      {:error, reason} ->
        {:error, %StoreError{action: :fetch_session, did: did, reason: reason}}
    end
  end

  defp refresh(config, did, stale_token) do
    result =
      config.store.update_session(did, fn session ->
        if session.access_token == stale_token do
          do_refresh(config, session)
        else
          {:ok, session}
        end
      end)

    case result do
      {:ok, session} ->
        {:ok, session}

      {:error, :not_found} ->
        {:error, %NoSession{did: did}}

      {:error, %RefreshFailed{}} = error ->
        error

      {:error, reason} ->
        {:error, %StoreError{action: :update_session, did: did, reason: reason}}
    end
  end

  defp do_refresh(config, session) do
    result =
      with {:ok, server} <- Discovery.discover(session.pds_endpoint) do
        Flow.refresh(server, session,
          client_id: config.client_id,
          client_jwk: config.signing_key
        )
      end

    with {:error, reason} <- result do
      {:error, %RefreshFailed{did: session.did, reason: reason}}
    end
  end

  defp expired?(session) do
    threshold = DateTime.add(DateTime.utc_now(), @refresh_buffer_seconds, :second)
    DateTime.compare(session.expires_at, threshold) != :gt
  end
end
