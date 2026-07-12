defmodule Latch.Config do
  @moduledoc """
  The configuration that drives the client. You can create many of these.

  ## Fields
    * `:store` - a module implementing `Latch.Store`
    * `:client_id` - the URL of the published client metadata document
    * `:redirect_uri` - the OAuth callback URL
    * `:scope` - the requsted scopes
    * `:signing_key` - the ES256 `JOSE.JWK` private key for `private_key_jwt`
    * `:client_name` - shown on the authorization consent screen
    * `:client_uri` - client home page
  """

  @default_request_ttl 600

  @enforce_keys [:store, :client_id, :redirect_uri, :scope, :signing_key]
  defstruct @enforce_keys ++ [:client_name, :client_uri, request_ttl: @default_request_ttl]

  @type t :: %__MODULE__{
          store: module(),
          client_id: String.t(),
          redirect_uri: String.t(),
          scope: String.t(),
          signing_key: JOSE.JWK.t(),
          client_name: String.t() | nil,
          client_uri: String.t() | nil
        }
end
