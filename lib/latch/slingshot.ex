defmodule Latch.Slingshot do
  @moduledoc """
  Very simple Slingshot client for fetching resolving identities.
  """

  # GET /xrpc/blue.microcosm.identity.resolveMiniDoc?identifier=<identifier>

  alias Latch.Error.IdentityMismatch
  alias Latch.HTTP

  @resolve "/xrpc/blue.microcosm.identity.resolveMiniDoc"
  @user_agent "latch (+https://tangled.org/jola.dev/latch)"
  @receive_timeout 5_000

  def resolve_identity(config, identifier) do
    url = "#{config.slingshot_url}#{@resolve}"
    headers = [{"user-agent", @user_agent}]

    opts =
      [
        params: %{identifier: identifier},
        headers: headers,
        receive_timeout: @receive_timeout
      ]

    with {:ok,
          %{
            "handle" => handle,
            "did" => did,
            "pds" => pds
          }} <- HTTP.get_json(config.pool, url, opts) do
      if handle == "handle.invalid" do
        {:error, %IdentityMismatch{reason: :handle_mismatch}}
      else
        {:ok, %{handle: handle, pds_endpoint: pds, did: did}}
      end
    end
  end
end
