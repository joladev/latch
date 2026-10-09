defmodule Latch.Slingshot do
  @moduledoc """
  Very simple Slingshot client for fetching resolving identities.
  """

  # GET /xrpc/blue.microcosm.identity.resolveMiniDoc?identifier=<identifier>

  alias Latch.Error.HandleNotFound
  alias Latch.Error.IdentityMismatch
  alias Latch.Error.InvalidResponse
  alias Latch.Error.SlingshotUnavailable
  alias Latch.HTTP

  @resolve "/xrpc/blue.microcosm.identity.resolveMiniDoc"
  @receive_timeout 5_000

  def resolve_identity(config, identifier) do
    url = "#{config.slingshot_url}#{@resolve}"

    opts =
      [
        params: %{identifier: identifier},
        receive_timeout: @receive_timeout
      ]

    case HTTP.get_json(config.pool, url, opts) do
      {:ok,
       %{
         "handle" => handle,
         "did" => did,
         "pds" => pds
       }} ->
        if handle == "handle.invalid" do
          {:error, %IdentityMismatch{reason: :handle_mismatch}}
        else
          {:ok, %{handle: handle, pds_endpoint: pds, did: did}}
        end

      {:error, %InvalidResponse{reason: {:http_status, 400}}} ->
        {:error, %HandleNotFound{reason: :handle_not_found}}

      {:error, error} ->
        {:error, %SlingshotUnavailable{error: error}}
    end
  end
end
