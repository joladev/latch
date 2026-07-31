defmodule Latch.AtURI do
  @moduledoc """
  at-uris are used to reference individual records within a repository, identified
  by `did` or handle. This module implements the restricted grammar used in Lexicons.

  ## The anatomy of an at-uri

      at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3k2u5kbfqzf2k
      \__/  \______________________________/ \______________/ \__________/
       |                 |                         |               |
       scheme         authority                collection       record key
      (always "at")  (DID or handle —          (NSID — the     (rkey — e.g.
                     whose repo this is)        lexicon type)   a TID)

  https://atproto.com/specs/at-uri-scheme
  """

  alias Latch.DID
  alias Latch.Handle
  alias Latch.NSID
  alias Latch.RecordKey

  @enforce_keys [:authority]
  defstruct @enforce_keys ++ [:collection, :rkey]

  @type t :: %__MODULE__{
          authority: String.t(),
          collection: String.t() | nil,
          rkey: String.t() | nil
        }

  @doc """
  Parse an at-uri string into an AtURI struct and validate against the spec.

  ## Examples
      iex> Latch.AtURI.parse("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3k2u5kbfqzf2k")
      {:ok, %Latch.AtURI{authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz", collection: "app.bsky.feed.post", rkey: "3k2u5kbfqzf2k"}}
  """
  @spec parse(String.t()) ::
          {:ok, t()}
          | {:error,
             :invalid_structure
             | :invalid_scheme
             | :invalid_authority
             | :invalid_collection
             | :invalid_rkey}

  def parse("at://" <> rest) do
    parts = String.split(rest, "/")

    with :ok <- check_structure(rest, parts),
         {:ok, uri} <- take_parts(parts),
         :ok <- check_authority(uri.authority),
         :ok <- check_collection(uri.collection),
         :ok <- check_rkey(uri.rkey) do
      {:ok, %__MODULE__{authority: uri.authority, collection: uri.collection, rkey: uri.rkey}}
    end
  end

  def parse(_invalid) do
    {:error, :invalid_scheme}
  end

  @doc """
  Create and validate an AtURI struct.

  ## Examples

      iex> Latch.AtURI.new("did:plc:bvraa6gajy4tfr3eh2sisdkr", "site.standard.publication", "3mope7jyypk22")
      {:ok, %Latch.AtURI{authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr", collection: "site.standard.publication", rkey: "3mope7jyypk22"}}
  """
  @spec new(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, t()}
          | {:error,
             :invalid_authority | :invalid_collection | :invalid_rkey | :missing_collection}
  def new(authority, collection \\ nil, rkey \\ nil) do
    with :ok <- check_authority(authority),
         :ok <- check_collection(collection),
         :ok <- check_rkey(rkey),
         :ok <- check_pairing(collection, rkey) do
      {:ok,
       %__MODULE__{
         authority: authority,
         collection: collection,
         rkey: rkey
       }}
    end
  end

  @doc """
  Same as `new/3` but raises on invalid inputs.

  ## Examples

      iex> Latch.AtURI.new!("did:plc:bvraa6gajy4tfr3eh2sisdkr", "site.standard.publication", "3mope7jyypk22")
      %Latch.AtURI{authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr", collection: "site.standard.publication", rkey: "3mope7jyypk22"}
  """
  @spec new!(String.t(), String.t() | nil, String.t() | nil) :: t()
  def new!(authority, collection \\ nil, rkey \\ nil) do
    {:ok, at_uri} = new(authority, collection, rkey)
    at_uri
  end

  @doc """
  Turns an AtURI struct into a proper at-uri string.

  ## Examples

      iex> at_uri = Latch.AtURI.new!("did:plc:bvraa6gajy4tfr3eh2sisdkr", "site.standard.publication", "3mope7jyypk22")
      iex> Latch.AtURI.to_string(at_uri)
      "at://did:plc:bvraa6gajy4tfr3eh2sisdkr/site.standard.publication/3mope7jyypk22"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = at_uri) do
    string =
      [at_uri.authority, at_uri.collection, at_uri.rkey]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("/")

    "at://" <> string
  end

  defp check_structure(rest, parts) do
    if String.contains?(rest, ["?", "#"]) or Enum.any?(parts, &(&1 == "")) do
      {:error, :invalid_structure}
    else
      :ok
    end
  end

  defp take_parts(parts) when length(parts) in 1..3 do
    {:ok,
     %{
       authority: Enum.at(parts, 0),
       collection: Enum.at(parts, 1),
       rkey: Enum.at(parts, 2)
     }}
  end

  defp take_parts(_parts) do
    {:error, :invalid_structure}
  end

  defp check_authority(authority) do
    if DID.valid?(authority) or Handle.valid?(authority) do
      :ok
    else
      {:error, :invalid_authority}
    end
  end

  defp check_collection(collection) do
    if is_nil(collection) or NSID.valid?(collection) do
      :ok
    else
      {:error, :invalid_collection}
    end
  end

  defp check_rkey(rkey) do
    if is_nil(rkey) or RecordKey.valid?(rkey) do
      :ok
    else
      {:error, :invalid_rkey}
    end
  end

  defp check_pairing(collection, rkey) do
    if not is_nil(rkey) and is_nil(collection) do
      {:error, :missing_collection}
    else
      :ok
    end
  end
end

defimpl String.Chars, for: Latch.AtURI do
  def to_string(at_uri), do: Latch.AtURI.to_string(at_uri)
end
