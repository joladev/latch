defmodule Latch.Identity do
  @moduledoc """
  Resolves an atproto handle to a verified identity.

  Resolution is bidirectional per the atproto identity spec, the handle is
  resolved to a DID and the DID document is fetched independently, and the
  docment's claimed handle must match the handle we started from. Neither
  direction alone is trusted, otherwise anyone could point DNS at a victim's
  DID.
  """

  alias Latch.DID
  alias Latch.DIDDocument
  alias Latch.DNS
  alias Latch.Error.HandleNotFound
  alias Latch.Error.IdentityMismatch
  alias Latch.Error.InvalidResponse
  alias Latch.Error.Transport
  alias Latch.Handle
  alias Latch.HTTP

  @plc_directory "https://plc.directory"

  @enforce_keys [:did, :handle, :pds_endpoint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t()
        }

  @doc """
  Resolves and verifies a handle, returning its DID and PDS endpoint.

  Returns structured `Latch.Error` exceptions describing resolution,
  identity-verifiction, and transport failures.
  """
  @spec resolve_handle(String.t()) ::
          {:ok, t()}
          | {:error,
             HandleNotFound.t() | IdentityMismatch.t() | InvalidResponse.t() | Transport.t()}
  def resolve_handle(handle) when is_binary(handle) do
    handle = Handle.normalize(handle)

    with :ok <- validate_handle(handle),
         {:ok, did} <- handle_to_did(handle),
         :ok <- validate_did(did, handle),
         {:ok, document} <- did_to_document(did, handle),
         {:ok, parsed} <- parse_did_document(document, did, handle),
         :ok <- confirm_bidirectional(parsed, handle) do
      {:ok, %__MODULE__{did: did, handle: handle, pds_endpoint: parsed.pds_endpoint}}
    end
  end

  defp validate_handle(handle) do
    if Handle.valid?(handle) do
      :ok
    else
      {:error, %HandleNotFound{handle: handle, reason: :invalid_handle}}
    end
  end

  # DNS TXT is preferred, the HTTPS well-known method is only consulated when
  # DNS returns no record. Conflicting DNS records hard-fail per spec.
  defp handle_to_did(handle) do
    case dns_did(handle) do
      {:ok, _did} = ok ->
        ok

      {:error, :ambiguous_dns} ->
        {:error, %HandleNotFound{handle: handle, reason: :ambiguous_dns}}

      :none ->
        https_did(handle)
    end
  end

  defp validate_did(did, handle) do
    if DID.valid?(did) do
      :ok
    else
      {:error, %IdentityMismatch{handle: handle, reason: :invalid_did}}
    end
  end

  defp dns_did(handle) do
    with_prefix = "_atproto." <> handle

    dids =
      with_prefix
      |> DNS.lookup_txt()
      |> Enum.flat_map(fn
        "did=" <> did -> [did]
        _ -> []
      end)
      |> Enum.uniq()

    case dids do
      [did] -> {:ok, did}
      [] -> :none
      _ -> {:error, :ambiguous_dns}
    end
  end

  defp https_did(handle) do
    case HTTP.get_text("https://" <> handle <> "/.well-known/atproto-did") do
      {:ok, body} ->
        {:ok, String.trim(body)}

      {:error, %InvalidResponse{reason: {:http_status, 404}}} ->
        {:error, %HandleNotFound{handle: handle, reason: :handle_not_found}}

      {:error, _reason} = error ->
        error
    end
  end

  defp did_to_document("did:plc:" <> _ = did, _handle) do
    fetch_did_document(@plc_directory <> "/" <> did)
  end

  defp did_to_document("did:web:" <> host, _handle) do
    fetch_did_document("https://" <> URI.decode(host) <> "/.well-known/did.json")
  end

  defp did_to_document(_did, handle) do
    {:error, %HandleNotFound{handle: handle, reason: :unsupported_did_method}}
  end

  defp fetch_did_document(url) do
    HTTP.get_json(url)
  end

  defp parse_did_document(document, did, handle) do
    with {:error, reason} <- DIDDocument.parse(document, did) do
      {:error, %IdentityMismatch{handle: handle, reason: reason}}
    end
  end

  defp confirm_bidirectional(%DIDDocument{handle: handle}, handle), do: :ok

  defp confirm_bidirectional(_parsed, handle),
    do: {:error, %IdentityMismatch{handle: handle, reason: :handle_mismatch}}
end
