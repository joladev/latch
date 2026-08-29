defmodule Latch.SpaceURITest do
  use ExUnit.Case, async: true

  alias Latch.SpaceURI

  describe "parse/1" do
    test "handles valid uris" do
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "general"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
               )

      # did:web authority; reserved-ish skey
      assert {:ok,
              %SpaceURI{
                authority: "did:web:example.com",
                type: "com.example.bookmarks",
                skey: "self"
              }} =
               SpaceURI.parse("at://did:web:example.com/space/com.example.bookmarks/self")

      # TID skey
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "3k2u5kbfqzf2k"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/3k2u5kbfqzf2k"
               )

      # colon in skey
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "literal:default"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/literal:default"
               )

      # underscore/tilde
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "my_forum~v2"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/my_forum~v2"
               )

      # skey length boundary
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: skey
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/#{String.duplicate("a", 512)}"
               )

      assert String.length(skey) == 512

      # author ≠ authority — a member's record in someone else's space (the shared-space case)
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "general",
                author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "com.atmoboards.thread",
                rkey: "3k2u5kbfqzf2k"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k"
               )

      # author == authority — personal data
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.example.bookmarks",
                skey: "self",
                author: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                collection: "com.example.bookmark",
                rkey: "3k2u5kbfqzf2k"
              }} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.example.bookmarks/self/did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.bookmark/3k2u5kbfqzf2k"
               )
    end

    test "returns useful errors" do
      # :invalid_scheme
      assert {:error, :invalid_scheme} =
               SpaceURI.parse(
                 "https://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
               )

      assert {:error, :invalid_scheme} =
               SpaceURI.parse(
                 "did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
               )

      # :invalid_structure
      # public URI, marker absent — the routing case
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3k2u5kbfqzf2k"
               )

      # marker only
      assert {:error, :invalid_structure} =
               SpaceURI.parse("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space")

      # missing skey
      assert {:error, :invalid_structure} =
               SpaceURI.parse("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum")

      # 5 segments
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr"
               )

      # 6 segments
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread"
               )

      # 8 segments
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k/extra"
               )

      # trailing slash
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/"
               )

      # empty segment
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum//general"
               )

      # marker is lowercase-literal
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/Space/com.atmoboards.forum/general"
               )

      # query
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general?foo=bar"
               )

      # fragment
      assert {:error, :invalid_structure} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general#frag"
               )

      # :invalid_authority
      # handle — DID-only per proposal
      assert {:error, :invalid_authority} =
               SpaceURI.parse("at://alice.example.com/space/com.atmoboards.forum/general")

      # :invalid_type
      # not an NSID (no dots)
      assert {:error, :invalid_type} =
               SpaceURI.parse("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/forum/general")

      # underscore fails NSID grammar
      assert {:error, :invalid_type} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.example.space_type/general"
               )

      # :invalid_skey
      assert {:error, :invalid_skey} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/."
               )

      assert {:error, :invalid_skey} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/.."
               )

      assert {:error, :invalid_skey} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/#{String.duplicate("a", 513)}"
               )

      # char outside [-._:~A-Za-z0-9]
      assert {:error, :invalid_skey} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/key!"
               )

      # :invalid_author
      # handle
      assert {:error, :invalid_author} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/alice.example.com/com.atmoboards.thread/3k2u5kbfqzf2k"
               )

      # :invalid_collection
      # not an NSID
      assert {:error, :invalid_collection} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/thread/3k2u5kbfqzf2k"
               )

      # :invalid_rkey
      assert {:error, :invalid_rkey} =
               SpaceURI.parse(
                 "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/."
               )
    end
  end

  describe "new/3" do
    test "builds valid SpaceURIs" do
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "general"
              }} =
               SpaceURI.new(
                 "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                 "com.atmoboards.forum",
                 "general"
               )
    end
  end

  describe "new!/3" do
    test "builds valid SpaceURIs" do
      assert %SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general"
             } =
               SpaceURI.new!(
                 "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                 "com.atmoboards.forum",
                 "general"
               )
    end
  end

  describe "new/6" do
    test "builds valid SpaceURIs" do
      assert {:ok,
              %SpaceURI{
                authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                type: "com.atmoboards.forum",
                skey: "general",
                author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "com.atmoboards.thread",
                rkey: "3k2u5kbfqzf2k"
              }} =
               SpaceURI.new(
                 "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                 "com.atmoboards.forum",
                 "general",
                 "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                 "com.atmoboards.thread",
                 "3k2u5kbfqzf2k"
               )
    end
  end

  describe "new!/6" do
    test "builds valid SpaceURIs" do
      assert %SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general",
               author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
               collection: "com.atmoboards.thread",
               rkey: "3k2u5kbfqzf2k"
             } =
               SpaceURI.new!(
                 "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
                 "com.atmoboards.forum",
                 "general",
                 "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                 "com.atmoboards.thread",
                 "3k2u5kbfqzf2k"
               )
    end
  end

  describe "to_string/1" do
    test "handles space references" do
      assert SpaceURI.to_string(%SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general"
             }) == "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
    end

    test "handles space records" do
      assert SpaceURI.to_string(%SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general",
               author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
               collection: "com.atmoboards.thread",
               rkey: "3k2u5kbfqzf2k"
             }) ==
               "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k"
    end
  end

  describe "to_ref/1" do
    test "strips record fields" do
      assert SpaceURI.to_ref(%SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general",
               author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
               collection: "com.atmoboards.thread",
               rkey: "3k2u5kbfqzf2k"
             }) == %SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general"
             }
    end
  end

  describe "record?/1" do
    test "recognizes full records" do
      assert SpaceURI.record?(%SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general",
               author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
               collection: "com.atmoboards.thread",
               rkey: "3k2u5kbfqzf2k"
             })

      refute SpaceURI.record?(%SpaceURI{
               authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
               type: "com.atmoboards.forum",
               skey: "general"
             })
    end
  end

  describe "space_uri?/1" do
    test "detects whether a URI string is a space URI" do
      assert SpaceURI.space_uri?(
               "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k"
             )

      assert SpaceURI.space_uri?(
               "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
             )

      refute SpaceURI.space_uri?("at://did:plc:bvraa6gajy4tfr3eh2sisdkr")
      refute SpaceURI.space_uri?("at://retr0.id/app.bsky.feed.post/3k5nobkf2w72g")

      refute SpaceURI.space_uri?("http://localhost:4000")
      refute SpaceURI.space_uri?("https://example.com")
    end
  end

  describe "String.Chars impl" do
    test "handles references" do
      space_uri = %SpaceURI{
        authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        type: "com.atmoboards.forum",
        skey: "general"
      }

      assert "#{space_uri}" ==
               "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general"
    end

    test "handles records" do
      space_uri = %SpaceURI{
        authority: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        type: "com.atmoboards.forum",
        skey: "general",
        author: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
        collection: "com.atmoboards.thread",
        rkey: "3k2u5kbfqzf2k"
      }

      assert "#{space_uri}" ==
               "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/com.atmoboards.forum/general/did:plc:bvraa6gajy4tfr3eh2sisdkr/com.atmoboards.thread/3k2u5kbfqzf2k"
    end
  end
end
