defmodule Latch do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  use Supervisor

  alias Latch.ClientMetadata
  alias Latch.Config
  alias Latch.Discovery
  alias Latch.DPoP
  alias Latch.Error.Discovery, as: DiscoveryError
  alias Latch.Error.HandleNotFound
  alias Latch.Error.IdentityMismatch
  alias Latch.Error.InvalidResponse
  alias Latch.Error.MissingDPoPNonce
  alias Latch.Error.NoSession
  alias Latch.Error.OAuth
  alias Latch.Error.RefreshFailed
  alias Latch.Error.SecurityViolation
  alias Latch.Error.Store, as: StoreError
  alias Latch.Error.Transport
  alias Latch.Error.XRPC, as: XRPCError
  alias Latch.Flow
  alias Latch.Identity
  alias Latch.PKCE
  alias Latch.Request

  @type name :: atom() | pid()

  @doc """
  Starts a Latch supervisor.

  See the module documentation for the supported options.

  ## Examples

      iex> {:ok, _pid} = Latch.start_link(name: LatchStartLinkExample, store: Latch.TestStore, mode: :confidential, client_id: "https://myapp.example/metadata.json", redirect_uri: "https://myapp.example/callback", scope: "atproto", signing_key: Jason.encode!(Latch.DPoP.generate_key()))
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    config = Config.build!(opts)

    Supervisor.start_link(__MODULE__, %{name: name, config: config}, name: name)
  end

  @doc """
  Returns a child specification to start Latch under a supervisor.

  ## Examples

      iex> Latch.child_spec(name: MyApp.Latch, store: MyApp.Store, client_id: "https://myapp.example/metadata.json", redirect_uri: "https://myapp.example/callback", scope: "atproto", signing_key: :test_key, mode: :confidential)
      %{id: MyApp.Latch, start: {Latch, :start_link, [[name: MyApp.Latch, store: MyApp.Store, client_id: "https://myapp.example/metadata.json", redirect_uri: "https://myapp.example/callback", scope: "atproto", signing_key: :test_key, mode: :confidential]]}, type: :supervisor}
  """
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

  @doc """
  Returns the client metadata map.

  Serve it as JSON at the URL configured as `:client_id`, e.g. from a
  controller: `json(conn, Latch.client_metadata(MyApp.Latch))`.
  """
  @spec client_metadata(name()) :: ClientMetadata.t()
  def client_metadata(name) do
    %Config{} = config = config(name)

    ClientMetadata.build(
      client_id: config.client_id,
      redirect_uris: [config.redirect_uri],
      scope: config.scope,
      jwk: config.signing_key,
      client_name: config.client_name,
      client_uri: config.client_uri,
      mode: config.mode
    )
  end

  @doc """
  Begins an authorization flow for `handle`.

  Resolves the handle to a DID and PDS, discovers the authorization
  server, pushes the authorization request (PAR), stores the in-flight
  request in the configured `Latch.Store`, and returns the URL to
  redirect the browser to.

  The stored request is single-use. `callback/2` consumes it.

  ## Examples

      iex> {:ok, _pid} = Latch.start_link(mode: :confidential, name: LatchAuthorizeExample, store: Latch.TestStore, client_id: "https://myapp.example/metadata.json", redirect_uri: "https://myapp.example/callback", scope: "atproto", signing_key: Jason.encode!(Latch.DPoP.generate_key()))
      iex> Latch.authorize(LatchAuthorizeExample, "not a handle")
      {:error, %Latch.Error.HandleNotFound{handle: "not a handle", reason: :invalid_handle}}
  """
  @spec authorize(name(), String.t()) ::
          {:ok, String.t()}
          | {:error,
             HandleNotFound.t()
             | IdentityMismatch.t()
             | DiscoveryError.t()
             | InvalidResponse.t()
             | MissingDPoPNonce.t()
             | OAuth.t()
             | StoreError.t()
             | Transport.t()}
  def authorize(name, handle) do
    %Config{} = config = config(name)

    verifier = PKCE.generate_verifier()
    dpop_key = DPoP.generate_key()
    state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    with {:ok, identity} <- Identity.resolve_handle(handle),
         {:ok, server} <-
           Discovery.discover(identity.pds_endpoint, allow_http: Config.localhost?(config)),
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

  @doc """
  Completes an authorization flow from the OAuth callback params.

  Consumes a stored request. Single use, so a replayed callback fails
  with `%Latch.Error.SecurityViolation{}`. Verifies the issuer, exchanges
  the code, stores the session using the `Latch.Store` implementation, and
  returns identity information.
  """
  @spec callback(name(), map()) ::
          {:ok, %{did: String.t(), handle: String.t()}}
          | {:error,
             InvalidResponse.t()
             | MissingDPoPNonce.t()
             | OAuth.t()
             | SecurityViolation.t()
             | StoreError.t()
             | Transport.t()}
  def callback(name, %{"state" => state} = params) when is_binary(state) do
    %Config{} = config = config(name)

    with {:ok, request} <- take_request(config, state) do
      complete_callback(params, request, config)
    end
  end

  def callback(_name, _params) do
    {:error, %InvalidResponse{reason: :unexpected_response}}
  end

  @doc """
  Deletes the session for `did`. Call this when the user logs out.
  """
  @spec delete_session(name(), String.t()) :: :ok | {:error, StoreError.t()}
  def delete_session(name, did) do
    %Config{} = config = config(name)

    with {:error, reason} <- config.store.delete_session(did) do
      {:error, %StoreError{action: :delete_session, did: did, reason: reason}}
    end
  end

  @doc """
  Query the user's PDS using their DID's session.

  `method` is the XRPC method NSID, eg `"com.atproto.repo.getRecord"`.
  `params` is passed as the query string.

  Assumes the session exists, that the user of that `did` is authenticated.
  If not, returns `{:error, %NoSession{}}`.

  ## Examples

      Latch.query(MyApp.Latch, "did:plc:abc123", "com.atproto.repo.getRecord", repo: "did:plc:abc123", collection: "app.bsky.feed.post", rkey: "3k2...")
  """
  @spec query(name(), String.t(), String.t(), Keyword.t()) ::
          {:ok, map()}
          | {:error,
             InvalidResponse.t()
             | MissingDPoPNonce.t()
             | NoSession.t()
             | RefreshFailed.t()
             | StoreError.t()
             | Transport.t()
             | XRPCError.t()}
  def query(name, did, method, params \\ []) do
    %Config{} = config = config(name)

    Latch.Client.query(config, did, method, params)
  end

  @doc """
  Performs a procedure against the user's PDS using their DID's session.

  ## Examples

      Latch.procedure(MyApp.Latch, "did:plc:abc123", "com.atproto.repo.putRecord", %{
        repo: "did:plc:abc123",
        collection: "app.bsky.feed.post",
        rkey: "3k2...",
        record: %{"$type" => "app.bsky.feed.post", "text" => "Hello!"}
      })
  """
  @spec procedure(name(), String.t(), String.t(), map()) ::
          {:ok, map()}
          | {:error,
             InvalidResponse.t()
             | MissingDPoPNonce.t()
             | NoSession.t()
             | RefreshFailed.t()
             | StoreError.t()
             | Transport.t()
             | XRPCError.t()}
  def procedure(name, did, method, body) do
    %Config{} = config = config(name)

    Latch.Client.procedure(config, did, method, body)
  end

  @doc """
  Upload a blob to the user's PDS using their DID's session.

  `content_type` is the blob's MIME type, eg `"image/png"`.
  """
  @spec upload_blob(name(), String.t(), binary(), String.t()) ::
          {:ok, map()}
          | {:error,
             InvalidResponse.t()
             | MissingDPoPNonce.t()
             | NoSession.t()
             | RefreshFailed.t()
             | StoreError.t()
             | Transport.t()
             | XRPCError.t()}
  def upload_blob(name, did, bytes, content_type) do
    %Config{} = config = config(name)

    Latch.Client.upload_blob(config, did, bytes, content_type)
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
    with :ok <- verify_issuer(request, issuer),
         {:ok, session} <-
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
           ),
         :ok <- store_session(config, session) do
      {:ok, %{did: session.did, handle: request.handle}}
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

  defp store_session(config, session) do
    with {:error, reason} <- config.store.put_session(session.did, session) do
      {:error, %StoreError{action: :put_session, did: session.did, reason: reason}}
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

  defp verify_issuer(%Request{issuer: issuer}, issuer), do: :ok

  defp verify_issuer(_request, _issuer) do
    {:error, %SecurityViolation{reason: :issuer_mismatch}}
  end

  defp config(name) do
    :persistent_term.get({__MODULE__, name})
  end
end
