defmodule Latch.TokenResponseTest do
  use ExUnit.Case, async: true

  alias Latch.TokenResponse

  @access_token "access_token"
  @refresh_token "refresh-token"
  @scope "atproto transition:generic"
  @sub "did:plc:bvraa6gajy4tfr3eh2sisdkr"

  @response %{
    "access_token" => @access_token,
    "refresh_token" => @refresh_token,
    "token_type" => "DPoP",
    "expires_in" => 3600,
    "scope" => @scope,
    "sub" => @sub
  }

  test "parses a valid DPoP token response with the atproto scope" do
    assert {:ok, token} = TokenResponse.parse(@response)

    assert token.access_token == @access_token
    assert token.refresh_token == @refresh_token
    assert token.scope == @scope
    assert token.sub == @sub
  end

  test "rejects a token response without the atproto scope" do
    response = %{@response | "scope" => "transition:generic"}

    assert {:error, {:invalid, "scope"}} = TokenResponse.parse(response)
  end
end
