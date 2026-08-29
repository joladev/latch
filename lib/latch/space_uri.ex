defmodule Latch.SpaceURI do
  @moduledoc """

  ## The anatomy of a space at-uri

      at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k
      \__/  \______________________________/ \___/ \________________/ \_____/ \______________________________/ \_________________/ \________/
       |                |                    |           |              |                 |                         |               |
      scheme       space authority         marker     space type      skey             author                   collection      record key
      (always      (DID — the space's     (literal   (NSID — the   (an rkey —      (DID — the member          (NSID — the     (rkey — e.g.
       "at")        root of access)        "space")   modality)     slug or TID)    whose repo holds           lexicon type)   a TID)
                                                                                   the record)

  https://atproto.com/blog/atproto-spaces-alpha
  """

  alias Latch.DID
  alias Latch.NSID
  alias Latch.RecordKey

  @enforce_keys [:authority, :type, :skey]
  defstruct @enforce_keys ++ [:author, :collection, :rkey]

  @doc """
  Parses space at-uris like at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general.
  """
  def parse("at://" <> rest) do
    parts = String.split(rest, "/")

    case parts do
      [authority, "space", type, skey] ->
        with :ok <- check_structure(rest, parts),
             :ok <- check_authority(authority),
             :ok <- check_type(type),
             :ok <- check_skey(skey) do
          {:ok,
           %__MODULE__{
             authority: authority,
             type: type,
             skey: skey
           }}
        end

      [authority, "space", type, skey, author, collection, rkey] ->
        with :ok <- check_structure(rest, parts),
             :ok <- check_authority(authority),
             :ok <- check_type(type),
             :ok <- check_skey(skey),
             :ok <- check_author(author),
             :ok <- check_collection(collection),
             :ok <- check_rkey(rkey) do
          {:ok,
           %__MODULE__{
             authority: authority,
             type: type,
             skey: skey,
             author: author,
             collection: collection,
             rkey: rkey
           }}
        end

      _other ->
        {:error, :invalid_structure}
    end
  end

  def parse(_), do: {:error, :invalid_scheme}

  def new(authority, type, skey) do
    with :ok <- check_authority(authority),
         :ok <- check_type(type),
         :ok <- check_skey(skey) do
      {:ok,
       %__MODULE__{
         authority: authority,
         type: type,
         skey: skey
       }}
    end
  end

  def new(authority, type, skey, author, collection, rkey) do
    with :ok <- check_authority(authority),
         :ok <- check_type(type),
         :ok <- check_skey(skey),
         :ok <- check_author(author),
         :ok <- check_collection(collection),
         :ok <- check_rkey(rkey) do
      {:ok,
       %__MODULE__{
         authority: authority,
         type: type,
         skey: skey,
         author: author,
         collection: collection,
         rkey: rkey
       }}
    end
  end

  def new!(authority, type, skey) do
    {:ok, space_uri} = new(authority, type, skey)
    space_uri
  end

  def new!(authority, type, skey, author, collection, rkey) do
    {:ok, space_uri} = new(authority, type, skey, author, collection, rkey)
    space_uri
  end

  def to_string(%__MODULE__{} = space_uri) do
    if record?(space_uri) do
      "at://#{space_uri.authority}/space/#{space_uri.type}/#{space_uri.skey}/#{space_uri.author}/#{space_uri.collection}/#{space_uri.rkey}"
    else
      "at://#{space_uri.authority}/space/#{space_uri.type}/#{space_uri.skey}"
    end
  end

  def to_ref(%__MODULE__{} = space_uri) do
    %__MODULE__{space_uri | author: nil, collection: nil, rkey: nil}
  end

  def record?(%__MODULE__{} = space_uri) do
    not is_nil(space_uri.author)
  end

  def space_uri?("at://" <> rest) do
    String.contains?(rest, "/space/")
  end

  def space_uri?(_other), do: false

  defp check_structure(rest, parts) do
    if String.contains?(rest, ["?", "#"]) or Enum.any?(parts, &(&1 == "")) do
      {:error, :invalid_structure}
    else
      :ok
    end
  end

  defp check_authority(authority) do
    if DID.valid?(authority) do
      :ok
    else
      {:error, :invalid_authority}
    end
  end

  defp check_author(author) do
    if DID.valid?(author) do
      :ok
    else
      {:error, :invalid_author}
    end
  end

  defp check_type(type) do
    if NSID.valid?(type) do
      :ok
    else
      {:error, :invalid_type}
    end
  end

  defp check_collection(collection) do
    if NSID.valid?(collection) do
      :ok
    else
      {:error, :invalid_collection}
    end
  end

  defp check_skey(skey) do
    if RecordKey.valid?(skey) do
      :ok
    else
      {:error, :invalid_skey}
    end
  end

  defp check_rkey(rkey) do
    if RecordKey.valid?(rkey) do
      :ok
    else
      {:error, :invalid_rkey}
    end
  end
end

defimpl String.Chars, for: Latch.SpaceURI do
  def to_string(at_uri), do: Latch.SpaceURI.to_string(at_uri)
end
