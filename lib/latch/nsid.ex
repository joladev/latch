defmodule Latch.NSID do
  @moduledoc """
  Namespaced identifiers are used in atproto to reference lexicons, XRPC endpoints, and more.

  An example is: `site.standard.document`.

  https://atproto.com/specs/nsid
  """

  @syntax ~r/^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(\.[a-zA-Z]([a-zA-Z0-9]{0,62})?)$/

  @doc """
  Validates the NSID against the specification.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(nsid) when is_binary(nsid) do
    byte_size(nsid) <= 317 and String.match?(nsid, @syntax)
  end

  @doc """
  Takes an NSID like `site.standard.document` and extracts the last part, `document`.
  """
  @spec name(String.t()) :: String.t()
  def name(nsid) do
    nsid
    |> String.split(".")
    |> List.last()
  end

  @doc """
  Takes an NSID like `site.standard.document` and extracts the authority part, `site.standard`.
  """
  @spec authority(String.t()) :: String.t()
  def authority(nsid) do
    nsid
    |> String.split(".")
    |> Enum.drop(-1)
    |> Enum.join(".")
  end
end
