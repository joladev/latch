defmodule Latch.ClientMetadata do
  @moduledoc """
  Client metadata document for atproto OAuth.

  Served at the `client_id` URL. Authorization servers fetch it to discover
  redirect URIs, scopes, and the client's public signing key.
  """

  alias Latch.ClientAssertion

  @type t :: map()

  @doc """
  Builds the client metadata document as a JSON-serializable map.

  ## Options
  - `:client_id` (required) - full URL of the metadata document itself
  - `:redirect_uris` (required) - list of callback URLs
  - `:scope` (required) - space-separated scopes, must include `atproto`
  - `:jwk` (required) - client signing key, only the public part is published
  - `:client_name` (optional)
  - `:client_uri` (optional) - must share the `client_id` hostname
  - `:mode` - `:confidential`, `:public` or `:localhost`
  """
  @spec build(keyword()) :: t()
  def build(opts) do
    scope = Keyword.fetch!(opts, :scope)

    if "atproto" not in String.split(scope, " ") do
      raise ArgumentError, "scope must include atproto, got #{inspect(scope)}"
    end

    client_id = Keyword.fetch!(opts, :client_id)
    redirect_uris = Keyword.fetch!(opts, :redirect_uris)
    client_name = Keyword.get(opts, :client_name)
    client_uri = Keyword.get(opts, :client_uri)
    mode = Keyword.fetch!(opts, :mode)

    %{
      "client_id" => client_id,
      "application_type" => application_type(mode),
      "grant_types" => ["authorization_code", "refresh_token"],
      "response_types" => ["code"],
      "redirect_uris" => redirect_uris,
      "scope" => scope,
      "dpop_bound_access_tokens" => true,
      "token_endpoint_auth_method" => auth_method(mode)
    }
    |> maybe_put("client_name", client_name)
    |> maybe_put("client_uri", client_uri)
    |> maybe_put("token_endpoint_auth_signing_alg", auth_alg(mode))
    |> maybe_put("jwks", jwks(mode, opts))
  end

  defp public_jwk(key_map) do
    jwk = JOSE.JWK.from(key_map)
    {_, public} = JOSE.JWK.to_public_map(jwk)
    Map.put(public, "kid", ClientAssertion.kid(key_map))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp application_type(:localhost), do: "native"
  defp application_type(_mode), do: "web"

  defp auth_method(:confidential), do: "private_key_jwt"
  defp auth_method(_mode), do: "none"

  defp auth_alg(:confidential), do: "ES256"
  defp auth_alg(_mode), do: nil

  defp jwks(:confidential, opts) do
    jwk_map = Keyword.fetch!(opts, :jwk)
    %{"keys" => [public_jwk(jwk_map)]}
  end

  defp jwks(_mode, _opts), do: nil
end
