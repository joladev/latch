defmodule Latch.DIDDocument do
  @moduledoc """
  Parses atproto DID documents to extract the claimed handle and PDS endpoint.

  Verifies the document's internal correctness only. The caller must confirm
  the handle resolves back to this DID (bidirectional verification) before
  trusting it.
  """

  alias Latch.Handle

  @pds_type "AtprotoPersonalDataServer"

  @enforce_keys [:did, :handle, :pds_endpoint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t()
        }

  @doc """
  Parses a decoded DID document for a given DID.

  The `did` argument is the DID that was resolved to obtain this document.
  It must match the document's `id`.
  """
  @spec parse(map(), String.t()) ::
          {:ok, t()} | {:error, :did_mismatch | :invalid_handle | :no_pds | :invalid_pds_endpoint}
  def parse(document, did) when is_map(document) and is_binary(did) do
    with :ok <- check_id(document, did),
         {:ok, handle} <- claimed_handle(document),
         {:ok, endpoint} <- pds_endpoint(document) do
      {:ok, %__MODULE__{did: did, handle: handle, pds_endpoint: endpoint}}
    end
  end

  defp check_id(document, did) do
    if Map.get(document, "id") == did do
      :ok
    else
      {:error, :did_mismatch}
    end
  end

  defp claimed_handle(document) do
    case Map.get(document, "alsoKnownAs", []) do
      aliases when is_list(aliases) ->
        if handle = Enum.find_value(aliases, &handle_from_alias/1) do
          {:ok, handle}
        else
          {:error, :invalid_handle}
        end

      _ ->
        {:error, :invalid_handle}
    end
  end

  defp handle_from_alias("at://" <> handle) do
    if Handle.valid?(handle), do: handle
  end

  defp handle_from_alias(_alias), do: nil

  defp pds_endpoint(document) do
    case Map.get(document, "service", []) do
      services when is_list(services) ->
        if service = Enum.find(services, &pds_service?/1) do
          validate_endpoint(Map.get(service, "serviceEndpoint"))
        else
          {:error, :no_pds}
        end

      _ ->
        {:error, :no_pds}
    end
  end

  defp pds_service?(%{"id" => id, "type" => @pds_type}) when is_binary(id) do
    String.ends_with?(id, "#atproto_pds")
  end

  defp pds_service?(_service), do: false

  # We allow both HTTPS and HTTP to support local development, but in the future
  # we may lock the HTTP option behind a local dev flag and be stricter.
  defp validate_endpoint(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, path: nil, query: nil, userinfo: nil}
      when scheme in ["https", "http"] and is_binary(host) and host != "" ->
        {:ok, url}

      _ ->
        {:error, :invalid_pds_endpoint}
    end
  end

  defp validate_endpoint(_), do: {:error, :invalid_pds_endpoint}
end
