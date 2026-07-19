defmodule Latch.XRPC do
  @moduledoc """
  DPoP-authenticated XRPC calls to a session's PDS.

  Each request carriers `Authorization: DPoP <token` and a DPoP proof bound to
  the acess token `ath`. The PDS issues its own DPoP nonces, so a request is
  attempted once and retried with the nonce the PDS returns. Token refresh and
  persistence are the caller's concerns, not this module's.
  """

  alias Latch.Config
  alias Latch.DPoP
  alias Latch.Error.InvalidResponse
  alias Latch.Error.MissingDPoPNonce
  alias Latch.Error.Transport
  alias Latch.Error.XRPC
  alias Latch.HTTP
  alias Latch.Session

  @type error ::
          InvalidResponse.t() | MissingDPoPNonce.t() | Transport.t() | XRPC.t()

  @doc """
  Performs and authenticated XRPC query against the session's PDS.
  """
  @spec query(Config.t(), Session.t(), String.t(), keyword()) :: {:ok, map()} | {:error, error()}
  def query(%Config{} = config, %Session{} = session, method, params \\ []) do
    request(
      config,
      session,
      "GET",
      session.pds_endpoint <> "/xrpc/" <> method <> query_string(params),
      nil
    )
  end

  @doc """
  Performs and authenticated XRPC procedure against the session's PDS.
  """
  @spec procedure(Config.t(), Session.t(), String.t(), map()) :: {:ok, map()} | {:error, error()}
  def procedure(%Config{} = config, %Session{} = session, method, body) do
    request(config, session, "POST", session.pds_endpoint <> "/xrpc/" <> method, {:json, body})
  end

  @doc """
  Uploads raw bytes of content_type as a blob, returning the response with
  the blog reference.
  """
  @spec upload_blob(Config.t(), Session.t(), binary(), String.t()) ::
          {:ok, map()} | {:error, error()}
  def upload_blob(%Config{} = config, %Session{} = session, bytes, content_type) do
    request(
      config,
      session,
      "POST",
      session.pds_endpoint <> "/xrpc/com.atproto.repo.uploadBlob",
      {:raw, bytes, content_type}
    )
  end

  defp request(%Config{} = config, %Session{} = session, http_method, url, body) do
    origin = origin(url)
    thumbprint = DPoP.thumbprint(session.dpop_key)

    nonce =
      case Latch.NonceCache.get_nonce(config, thumbprint, origin) do
        {:ok, nonce} -> nonce
        :error -> nil
      end

    send_dpop(config, session, http_method, url, body, origin, thumbprint, nonce)
  end

  defp send_dpop(
         %Config{} = config,
         %Session{} = session,
         http_method,
         url,
         body,
         origin,
         thumbprint,
         nonce
       ) do
    proof =
      DPoP.proof(session.dpop_key, http_method, url,
        nonce: nonce,
        access_token: session.access_token
      )

    headers = [{"authorization", "DPoP #{session.access_token}"}, {"dpop", proof}]

    with {:ok, %{status: status, body: raw, headers: resp_headers}} <-
           HTTP.request(http_method, url, headers, body) do
      if fresh = nonce_header(resp_headers) do
        Latch.NonceCache.put_nonce(config, thumbprint, origin, fresh)
      end

      if needs_nonce?(status, resp_headers) do
        retry_with_nonce(
          config,
          session,
          http_method,
          url,
          body,
          origin,
          thumbprint,
          resp_headers
        )
      else
        handle_response(status, raw)
      end
    end
  end

  defp handle_response(status, raw) do
    with {:ok, decoded} <- decode_json(raw) do
      if status in 200..299 do
        {:ok, decoded}
      else
        {:error, %XRPC{status: status, body: decoded}}
      end
    end
  end

  defp retry_with_nonce(
         %Config{} = config,
         %Session{} = session,
         http_method,
         url,
         body,
         origin,
         thumbprint,
         headers
       ) do
    if nonce = nonce_header(headers) do
      send_dpop(config, session, http_method, url, body, origin, thumbprint, nonce)
    else
      {:error, %MissingDPoPNonce{}}
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

  defp needs_nonce?(401, headers) do
    case Map.fetch(headers, "www-authenticate") do
      {:ok, headers} ->
        Enum.any?(headers, &String.contains?(&1, "use_dpop_nonce"))

      :error ->
        false
    end
  end

  defp needs_nonce?(_status, _headers), do: false

  defp nonce_header(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> nonce
      _ -> nil
    end
  end

  defp decode_json(raw) do
    case Jason.decode(raw) do
      {:ok, %{} = json} -> {:ok, json}
      {:ok, _json} -> {:error, %InvalidResponse{reason: :unexpected_response}}
      {:error, _reason} -> {:error, %InvalidResponse{reason: :invalid_json}}
    end
  end

  defp query_string([]), do: ""
  defp query_string(params), do: "?" <> URI.encode_query(params)
end
