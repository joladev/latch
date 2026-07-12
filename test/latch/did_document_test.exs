defmodule Latch.DidDocumentTest do
  use ExUnit.Case, async: true

  alias Latch.DIDDocument

  @did "did:plc:bvraa6gajy4tfr3eh2sisdkr"

  test "parses a did document with an HTTPS PDS endpoint" do
    assert {:ok, document} = DIDDocument.parse(document(), @did)

    assert document.did == @did
    assert document.handle == "alice.example.com"
    assert document.pds_endpoint == "https://pds.example.com"
  end

  test "returns errors for malformed collection fields" do
    assert {:error, :invalid_handle} =
             DIDDocument.parse(%{document() | "alsoKnownAs" => "at://alice.example.com"}, @did)

    assert {:error, :no_pds} = DIDDocument.parse(%{document() | "service" => %{}}, @did)
  end

  defp document(endpoint \\ "https://pds.example.com") do
    %{
      "id" => @did,
      "alsoKnownAs" => ["at://alice.example.com"],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => endpoint
        }
      ]
    }
  end
end
