defmodule Latch.Public do
  @moduledoc """
  A non-authenticated companion for the Latch module.
  """

  alias Latch.Config
  alias Latch.Error.InvalidResponse
  alias Latch.Error.Transport
  alias Latch.HTTP

  @doc """
  Makes unauthenticated requests against any XRPC compatible server, including
  PDSs and Slingshot.

  ## Example

    iex> Latch.Public.query(MyApp.Latch, "https://slingshot.cove.town", "com.atproto.repo.getRecord", params: [repo: "did:plc:abc123", collection: "app.bsky.feed.post", rkey: "3k2..."])
  """
  @spec query(Latch.name(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Transport.t() | InvalidResponse.t()}
  def query(name, base, method, opts) do
    %Config{} = config = config(name)
    url = "#{base}/xrpc/#{method}"
    HTTP.get_json(config.pool, url, opts)
  end

  defp config(name) do
    :persistent_term.get({Latch, name})
  end
end
