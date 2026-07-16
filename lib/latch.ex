defmodule Latch do
  @moduledoc """
  A library for building atproto OAuth integrations. Stateless.
  """

  use Supervisor

  alias Latch.Config
  alias Latch.Discovery
  alias Latch.DPoP
  alias Latch.Error.InvalidResponse
  alias Latch.Error.OAuth
  alias Latch.Error.SecurityViolation
  alias Latch.Error.Store, as: StoreError
  alias Latch.Flow
  alias Latch.Identity
  alias Latch.PKCE
  alias Latch.Request
  alias Latch.Session

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    config = Config.build!(opts)

    Supervisor.start_link(__MODULE__, %{name: name, config: config}, name: name)
  end

  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: name,
      type: :supervisor,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl Supervisor
  def init(%{name: name, config: config}) do
    :persistent_term.put({__MODULE__, self()}, config)
    :persistent_term.put({__MODULE__, name}, config)

    Supervisor.init(
      [
        {Latch.NonceCache, config: config, name: name}
      ],
      strategy: :one_for_one
    )
  end

  def client_metadata(name) do
    %Config{} = config = config(name)

    Latch.ClientMetadata.build(
      client_id: config.client_id,
      redirect_uris: [config.redirect_uri],
      scope: config.scope,
      jwk: config.signing_key,
      client_name: config.client_name,
      client_uri: config.client_uri
    )
  end

  def authorize(name, handle) do
    %Config{} = config = config(name)

    verifier = PKCE.generate_verifier()
    dpop_key = DPoP.generate_key()
    state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    with {:ok, identity} <- Identity.resolve_handle(handle),
         {:ok, server} <- Discovery.discover(identity.pds_endpoint),
         {:ok, request_uri} <-
           Flow.par(config, server,
             client_id: config.client_id,
             client_jwk: config.signing_key,
             redirect_uri: config.redirect_uri,
             scope: config.scope,
             state: state,
             code_challenge: PKCE.challenge(verifier),
             dpop_key: dpop_key,
             login_hint: identity.handle
           ),
         request = %Request{
           state: state,
           did: identity.did,
           handle: identity.handle,
           pds_endpoint: identity.pds_endpoint,
           issuer: server.issuer,
           token_endpoint: server.token_endpoint,
           pkce_verifier: verifier,
           dpop_key: dpop_key
         },
         :ok <- store_request(config, request) do
      {:ok, Flow.authorization_url(server, config.client_id, request_uri)}
    end
  end

  def callback(name, %{"state" => state} = params) when is_binary(state) do
    %Config{} = config = config(name)

    with {:ok, request} <- take_request(config, state),
         :ok <- verify_state(request, state) do
      complete_callback(params, request, config)
    end
  end

  def callback(_name, _params) do
    {:error, %InvalidResponse{reason: :unexpected_response}}
  end

  def refresh(name, %Session{} = session) do
    %Config{} = config = config(name)

    with {:ok, server} <- Discovery.discover(session.pds_endpoint) do
      Flow.refresh(config, server, session,
        client_id: config.client_id,
        client_jwk: config.signing_key
      )
    end
  end

  defp complete_callback(
         %{"error" => error, "iss" => issuer} = params,
         request,
         _config
       )
       when is_binary(error) do
    with :ok <- verify_issuer(request, issuer) do
      {:error,
       %OAuth{
         error: error,
         description: Map.get(params, "error_description"),
         error_uri: Map.get(params, "error_uri")
       }}
    end
  end

  defp complete_callback(
         %{"code" => code, "iss" => issuer},
         %Request{} = request,
         config
       )
       when is_binary(code) do
    with :ok <- verify_issuer(request, issuer) do
      Flow.exchange_code(config,
        client_id: config.client_id,
        client_jwk: config.signing_key,
        redirect_uri: config.redirect_uri,
        code: code,
        code_verifier: request.pkce_verifier,
        dpop_key: request.dpop_key,
        expected_did: request.did,
        pds_endpoint: request.pds_endpoint,
        issuer: request.issuer,
        token_endpoint: request.token_endpoint
      )
    end
  end

  defp complete_callback(_params, _request, _config) do
    {:error, %InvalidResponse{reason: :unexpected_response}}
  end

  defp store_request(config, request) do
    with {:error, reason} <- config.store.put_request(request.state, request, config.request_ttl) do
      {:error,
       %StoreError{
         action: :put_request,
         did: request.did,
         reason: reason
       }}
    end
  end

  defp take_request(config, state) do
    case config.store.take_request(state) do
      {:ok, %Request{} = request} ->
        {:ok, request}

      {:error, :not_found} ->
        {:error, %SecurityViolation{reason: :state_mismatch}}

      {:error, reason} ->
        {:error, %StoreError{action: :take_request, did: nil, reason: reason}}
    end
  end

  defp verify_state(%Request{state: state}, state), do: :ok

  defp verify_state(_request, _state) do
    {:error, %SecurityViolation{reason: :state_mismatch}}
  end

  defp verify_issuer(%Request{issuer: issuer}, issuer), do: :ok

  defp verify_issuer(_request, _issuer) do
    {:error, %SecurityViolation{reason: :issuer_mismatch}}
  end

  defp config(name) do
    :persistent_term.get({__MODULE__, name})
  end
end
