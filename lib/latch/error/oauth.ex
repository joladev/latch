defmodule Latch.Error.OAuth do
  @moduledoc """
  The authorization server returned an OAuth error response.

  The `error` field contains the RFC 6749 error code.

  ## Common `error` values
    * `"access_denied"` - the user declined consent
    * `"invalid_grant"` - the code or refresh token is stale
    * `"invalid_client"` - client assertion rejected
    * `"invalid_request"` - malformed request to the server
    * `"expired_token"` - a DPoP nonce or token expired
  """

  defexception [:error, :description, :error_uri]

  @type t :: %__MODULE__{
          error: String.t(),
          description: String.t() | nil,
          error_uri: String.t() | nil
        }

  @impl Exception
  def message(%__MODULE__{} = error) do
    details =
      [error.description, error.error_uri]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" - ")

    case details do
      "" -> "OAuth error: #{error.error}"
      details -> "OAuth error: #{error.error} - #{details}"
    end
  end
end
