defmodule Latch.Discovery do
  @moduledoc """
  Discovers the authorization server for a PDS and validates the binding
  between them, per the atproto OAuth profile.

  The PDS publishes `/.well-known/oauth-protected-resource` naming its
  authorization server, that server's metadata `issuer` must in turn match
  the URL it was discovered at. Both directions are checked before the
  metadata is trusted.
  """

  alias Latch.Error.Discovery, as: DiscoveryError
  alias Latch.Error.Transport
  alias Latch.HTTP
  alias Latch.ServerMetadata

  @protected_resource_path "/.well-known/oauth-protected-resource"
  @auth_server_path "/.well-known/oauth-authorization-server"

  @doc """
  Resolves a PDS endpoint to its authorization server metadata.
  """
  @spec discover(String.t()) ::
          {:ok, ServerMetadata.t()}
          | {:error, DiscoveryError.t() | Transport.t()}
  def discover(pds_endpoint) when is_binary(pds_endpoint) do
    with {:ok, resource} <- HTTP.get_json(pds_endpoint <> @protected_resource_path),
         {:ok, issuer} <- authorization_server(resource, pds_endpoint),
         {:ok, metadata} <- HTTP.get_json(issuer <> @auth_server_path),
         {:ok, server} <- parse_server_metadata(metadata, pds_endpoint),
         :ok <- verify_issuer(server, issuer, pds_endpoint) do
      {:ok, server}
    end
  end

  defp authorization_server(resource, pds_endpoint) do
    with :ok <- verify_resource(resource, pds_endpoint) do
      case Map.get(resource, "authorization_servers") do
        # There has to be exactly one issuer according to the spec.
        [issuer] when is_binary(issuer) ->
          validate_authorization_server(issuer, pds_endpoint)

        _ ->
          {:error,
           %DiscoveryError{
             pds_endpoint: pds_endpoint,
             reason: :no_authorization_server
           }}
      end
    end
  end

  defp validate_authorization_server(issuer, pds_endpoint) do
    case URI.parse(issuer) do
      %URI{
        scheme: scheme,
        host: host,
        path: nil,
        query: nil,
        fragment: nil,
        userinfo: nil
      }
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, issuer}

      _ ->
        {:error,
         %DiscoveryError{
           pds_endpoint: pds_endpoint,
           reason: :invalid_authorization_server
         }}
    end
  end

  defp verify_resource(%{"resource" => resource}, resource), do: :ok

  defp verify_resource(_resource, pds_endpoint) do
    {:error,
     %DiscoveryError{
       pds_endpoint: pds_endpoint,
       reason: :resource_mismatch
     }}
  end

  defp verify_issuer(%ServerMetadata{issuer: issuer}, issuer, _pds_endpoint), do: :ok

  defp verify_issuer(_server, _issuer, pds_endpoint) do
    {:error,
     %DiscoveryError{
       pds_endpoint: pds_endpoint,
       reason: :issuer_mismatch
     }}
  end

  defp parse_server_metadata(metadata, pds_endpoint) do
    case ServerMetadata.parse(metadata) do
      {:ok, server} ->
        {:ok, server}

      {:error, {:missing, field}} ->
        {:error,
         %DiscoveryError{
           pds_endpoint: pds_endpoint,
           reason: {:missing_metadata, field}
         }}

      {:error, {:invalid, field}} ->
        {:error,
         %DiscoveryError{
           pds_endpoint: pds_endpoint,
           reason: {:invalid_metadata, field}
         }}
    end
  end
end
