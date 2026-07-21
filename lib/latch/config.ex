defmodule Latch.Config do
  @moduledoc """
  The configuration that drives the client.

  ## Fields
    * `:store` - a module implementing `Latch.Store`
    * `:client_id` - the URL of the published client metadata document
    * `:redirect_uri` - the OAuth callback URL
    * `:scope` - the requsted scopes
    * `:signing_key` - the ES256 `JOSE.JWK` private key for `private_key_jwt` as string
    * `:client_name` - shown on the authorization consent screen
    * `:client_uri` - client home page
    * `:name` - the name of the Latch instance
  """

  @default_request_ttl 600

  @enforce_keys [:store, :client_id, :redirect_uri, :scope, :signing_key, :name]
  defstruct @enforce_keys ++ [:client_name, :client_uri, request_ttl: @default_request_ttl]

  @type t :: %__MODULE__{
          store: module(),
          client_id: String.t(),
          redirect_uri: String.t(),
          scope: String.t(),
          signing_key: String.t(),
          name: atom() | pid(),
          client_name: String.t() | nil,
          client_uri: String.t() | nil,
          request_ttl: pos_integer()
        }

  @schema [
    store: [type: :atom, required: true],
    client_id: [type: :string, required: true],
    redirect_uri: [type: :string, required: true],
    scope: [type: :string, required: true],
    signing_key: [type: :string, required: true],
    name: [type: {:or, [:atom, :pid]}, required: true],
    client_name: [type: :string, required: false],
    client_uri: [type: :string, required: false],
    request_ttl: [type: :pos_integer, required: false, default: @default_request_ttl]
  ]

  @doc false
  def build!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)

    struct!(
      __MODULE__,
      store: validated[:store],
      client_id: validated[:client_id],
      redirect_uri: validated[:redirect_uri],
      scope: validated[:scope],
      signing_key: Jason.decode!(validated[:signing_key]),
      name: validated[:name],
      client_name: validated[:client_name],
      client_uri: validated[:client_uri],
      request_ttl: validated[:request_ttl]
    )
  end
end
