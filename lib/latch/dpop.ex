defmodule Latch.DPoP do
  @moduledoc """
  DPoP (RFC 9449) proof JWTs for atproto OAuth, and server-issued nonce flow
  shared by `Latch.XRPC` and `Latch.Flow`.
  """

  alias Latch.Config
  alias Latch.Error.InvalidResponse
  alias Latch.Error.MissingDPoPNonce
  alias Latch.Error.OAuth
  alias Latch.Error.Transport
  alias Latch.Error.XRPC
  alias Latch.NonceCache
  alias Latch.PKCE

  @curve "P-256"
  @algorithm "ES256"
  @jwt_type "dpop+jwt"

  @doc """
  Generates a new ES256 (P-256) key pair as a plain RFC 7517 JWK map.
  """
  @spec generate_key() :: map()
  def generate_key do
    key = JOSE.JWK.generate_key({:ec, @curve})
    {_, map} = JOSE.JWK.to_map(key)
    map
  end

  @doc """
  Signs a DPoP proof JWT for an HTTP request.
  ## Arguments
  - `jwk` — private plain JWK map for this OAuth session
  - `method` — HTTP method (e.g. `"POST"`)
  - `url` — request URL; query string is stripped for `htu` per atproto
  ## Options
  - `:nonce` — server DPoP nonce (omit when unknown)
  - `:access_token` — adds `ath` (S256 hash) for PDS/resource requests
  - `:jti` — override `jti` (tests)
  - `:iat` — override `iat` (tests)
  Note: atproto currently says **do not** include `iss` on PDS-bound proofs.
  """
  @spec proof(map(), String.t(), String.t(), keyword()) :: String.t()
  def proof(key_map, method, url, opts \\ []) do
    jwk = JOSE.JWK.from(key_map)

    jti = Keyword.get(opts, :jti, random_b64(20))
    iat = Keyword.get(opts, :iat, System.os_time(:second))
    nonce = Keyword.get(opts, :nonce)
    access_token = Keyword.get(opts, :access_token)

    {_, public_jwk} = JOSE.JWK.to_public_map(jwk)

    jws = %{
      "alg" => @algorithm,
      "typ" => @jwt_type,
      "jwk" => public_jwk
    }

    claims =
      %{
        "jti" => jti,
        "htm" => String.upcase(method),
        "htu" => htu(url),
        "iat" => iat
      }
      |> maybe_put("nonce", nonce)
      |> maybe_put("ath", access_token && access_token_hash(access_token))

    jwk
    |> JOSE.JWT.sign(jws, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc """
  S256 hash of an access token for the `ath` claim (same as PKCE S256)
  """
  @spec access_token_hash(String.t()) :: String.t()
  def access_token_hash(access_token) when is_binary(access_token) do
    PKCE.challenge(access_token)
  end

  @doc """
  RFC 7638 thumbprint of a plain JWK map.
  """
  @spec thumbprint(map()) :: String.t()
  def thumbprint(key_map) do
    key_map
    |> JOSE.JWK.from()
    |> JOSE.JWK.thumbprint()
  end

  @doc """
  Plumbing for the DPoP-nonce flow used in `Latch.Flow` and `Latch.XRPC`. This wraps
  the logic for getting nonces, caching new ones, and retrying challenges like 4xx responses.
  """
  @type send_error :: InvalidResponse.t() | OAuth.t() | Transport.t() | XRPC.t()
  @type send_result ::
          {{:ok, map()} | :challenge | {:error, send_error()}, String.t() | nil}
  @spec with_nonce(Config.t(), map(), String.t(), (String.t() | nil -> send_result())) ::
          {:ok, map()}
          | {:error, MissingDPoPNonce.t() | send_error()}
  def with_nonce(%Config{} = config, dpop_key, url, send) do
    origin = origin(url)
    thumbprint = thumbprint(dpop_key)

    nonce =
      case NonceCache.get_nonce(config, thumbprint, origin) do
        {:ok, nonce} -> nonce
        :error -> nil
      end

    attempt(config, thumbprint, origin, send, nonce, true)
  end

  @doc """
  Extract `dpop-nonce` header from a map of headers.
  """
  @spec nonce_header(map()) :: String.t() | nil
  def nonce_header(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> nonce
      _ -> nil
    end
  end

  defp htu(url) do
    url
    |> URI.parse()
    |> Map.put(:query, nil)
    |> Map.put(:fragment, nil)
    |> URI.to_string()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp random_b64(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp attempt(config, thumbprint, origin, send, nonce, retry?) do
    {result, fresh_nonce} = send.(nonce)

    if fresh_nonce do
      NonceCache.put_nonce(config, thumbprint, origin, fresh_nonce)
    end

    case result do
      :challenge when retry? and is_binary(fresh_nonce) ->
        attempt(config, thumbprint, origin, send, fresh_nonce, false)

      :challenge ->
        {:error, %MissingDPoPNonce{}}

      _ ->
        result
    end
  end

  defp origin(url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(url)
    default = if scheme == "https", do: 443, else: 80

    if is_nil(port) or port == default do
      "#{scheme}://#{host}"
    else
      "#{scheme}://#{host}:#{port}"
    end
  end
end
