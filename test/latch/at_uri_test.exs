defmodule Latch.AtURITest do
  use ExUnit.Case, async: true
  doctest Latch.AtURI

  alias Latch.AtURI

  describe "parse/1" do
    test "authority only" do
      # handle
      assert {:ok,
              %AtURI{
                authority: "foo.com"
              }} = AtURI.parse("at://foo.com")

      # did
      assert {:ok,
              %AtURI{
                authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr"
              }} = AtURI.parse("at://did:plc:bvraa6gajy4tfr3eh2sisdkr")
    end

    test "authority+collection" do
      # handle
      assert {:ok,
              %AtURI{
                authority: "retr0.id",
                collection: "app.bsky.feed.post"
              }} = AtURI.parse("at://retr0.id/app.bsky.feed.post")

      # did
      assert {:ok,
              %AtURI{
                authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "app.bsky.feed.post"
              }} = AtURI.parse("at://did:plc:bvraa6gajy4tfr3eh2sisdkr/app.bsky.feed.post")
    end

    test "authority+collection+rkey" do
      # numeric
      assert {:ok,
              %AtURI{
                authority: "foo.com",
                collection: "com.example.foo",
                rkey: "123"
              }} = AtURI.parse("at://foo.com/com.example.foo/123")

      # tid
      assert {:ok,
              %AtURI{
                authority: "retr0.id",
                collection: "app.bsky.feed.post",
                rkey: "3k5nobkf2w72g"
              }} = AtURI.parse("at://retr0.id/app.bsky.feed.post/3k5nobkf2w72g")

      assert {:ok,
              %AtURI{
                authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "app.bsky.feed.post",
                rkey: "3k5nobkf2w72g"
              }} =
               AtURI.parse(
                 "at://did:plc:bvraa6gajy4tfr3eh2sisdkr/app.bsky.feed.post/3k5nobkf2w72g"
               )

      # literal:self
      assert {:ok,
              %AtURI{
                authority: "did:web:example.com",
                collection: "app.bsky.actor.profile",
                rkey: "self"
              }} = AtURI.parse("at://did:web:example.com/app.bsky.actor.profile/self")

      assert {:ok,
              %AtURI{
                authority: "foo.com",
                collection: "app.bsky.actor.profile",
                rkey: "self"
              }} = AtURI.parse("at://foo.com/app.bsky.actor.profile/self")

      # tilde
      assert {:ok,
              %AtURI{
                authority: "foo.com",
                collection: "app.bsky.feed.post",
                rkey: "~"
              }} = AtURI.parse("at://foo.com/app.bsky.feed.post/~")

      # messy
      assert {:ok,
              %AtURI{
                authority: "foo.com",
                collection: "app.bsky.feed.post",
                rkey: "a:b-c_d.e"
              }} = AtURI.parse("at://foo.com/app.bsky.feed.post/a:b-c_d.e")
    end

    test "validation" do
      # wrong scheme
      assert {:error, :invalid_scheme} = AtURI.parse("https://foo.com/app.bsky.feed.post/abc")

      # trailing slash
      assert {:error, :invalid_structure} = AtURI.parse("at://foo.com/")

      # empty authority
      assert {:error, :invalid_structure} = AtURI.parse("at:///app.bsky.feed.post/abc")

      # empty segment
      assert {:error, :invalid_structure} = AtURI.parse("at://foo.com//app.bsky.feed.post")

      # too many segments
      assert {:error, :invalid_structure} = AtURI.parse("at://foo.com/a/b/c/d")

      # query
      assert {:error, :invalid_structure} = AtURI.parse("at://foo.com/app.bsky.feed.post/abc?x=1")

      # fragment
      assert {:error, :invalid_structure} =
               AtURI.parse("at://foo.com/app.bsky.feed.post/abc#frag")

      # user info
      assert {:error, :invalid_authority} = AtURI.parse("at://user:pass@foo.com")

      # port
      assert {:error, :invalid_authority} = AtURI.parse("at://example.com:3000")

      # lacking did/handle
      assert {:error, :invalid_authority} = AtURI.parse("at://computer")

      # NSID requires 3+ segments
      assert {:error, :invalid_collection} = AtURI.parse("at://foo.com/example/123")

      # single segment
      assert {:error, :invalid_collection} = AtURI.parse("at://foo.com/app")

      # space not allowed
      assert {:error, :invalid_rkey} = AtURI.parse("at://foo.com/app.bsky.feed.post/bad key")

      # literal . forbidden
      assert {:error, :invalid_rkey} = AtURI.parse("at://foo.com/app.bsky.feed.post/.")

      # literal .. forbidden
      assert {:error, :invalid_rkey} = AtURI.parse("at://foo.com/app.bsky.feed.post/..")
    end
  end

  describe "new/3" do
    test "builds at-uris" do
      assert {:ok,
              %AtURI{
                authority: "jola.dev"
              }} = AtURI.new("jola.dev")

      assert {:ok,
              %AtURI{
                authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "site.standard.publication"
              }} = AtURI.new("did:plc:bvraa6gajy4tfr3eh2sisdkr", "site.standard.publication")

      assert {:ok,
              %AtURI{
                authority: "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                collection: "site.standard.publication",
                rkey: "3mope7jyypk22"
              }} =
               AtURI.new(
                 "did:plc:bvraa6gajy4tfr3eh2sisdkr",
                 "site.standard.publication",
                 "3mope7jyypk22"
               )
    end

    test "validation" do
      assert {:error, :invalid_authority} = AtURI.new("user:pass@foo.com")
      assert {:error, :invalid_collection} = AtURI.new("jola.dev", "example")
      assert {:error, :invalid_rkey} = AtURI.new("jola.dev", "site.standard.document", "bad key")

      # can't pass an rkey without a collection
      assert {:error, :missing_collection} = AtURI.new("jola.dev", nil, "3mope7jyypk22")
    end
  end

  describe "new!/3" do
    test "returns %AtURI{}" do
      assert %AtURI{} = AtURI.new!("jola.dev")
    end

    test "raises on error" do
      assert_raise MatchError, fn ->
        AtURI.new!(".")
      end
    end
  end

  describe "to_string/1" do
    test "produces correctly formatted at-uris" do
      expected = "at://did:plc:bvraa6gajy4tfr3eh2sisdkr/app.bsky.feed.post/3k5nobkf2w72g"
      assert {:ok, %AtURI{} = struct} = AtURI.parse(expected)
      assert expected == AtURI.to_string(struct)
    end
  end
end
