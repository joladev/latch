defmodule Latch.PublicTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Latch.DPoP

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"
  @client_id_path "/oauth-client-metadata.json"
  @redirect_uri_path "/oauth/callback"

  describe "query/4" do
    test "makes an unauthenticated query" do
      pid =
        start_latch(
          store: Latch.TestStore,
          client_id_path: @client_id_path,
          redirect_uri_path: @redirect_uri_path,
          scope: "atproto",
          signing_key: Jason.encode!(DPoP.generate_key()),
          mode: :confidential,
          base_url_fun: fn -> "https://client.example.com" end
        )

      expect(Latch.HTTP, :get_json, fn _pool, _url, _opts ->
        {:ok,
         %{
           "record" => %{
             "$type" => "app.bsky.feed.post"
           }
         }}
      end)

      assert {:ok,
              %{
                "record" => %{
                  "$type" => "app.bsky.feed.post"
                }
              }} =
               Latch.Public.query(
                 pid,
                 "https://slingshot.cove.town",
                 "com.atproto.repo.getRecord",
                 params: [
                   repo: @did,
                   rkey: "rkey",
                   collection: "app.bsky.feed.post"
                 ]
               )
    end
  end

  defp start_latch(opts) do
    name = String.to_atom("latch_#{inspect(self())}")
    opts = Keyword.put(opts, :name, name)
    start_link_supervised!({Latch, opts})
  end
end
