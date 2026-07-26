defmodule Latch.Config do
  @moduledoc """
  The configuration that drives the client.

  ## Fields
    * `:store` - a module implementing `Latch.Store`
    * `:name` - the name of the Latch instance
    * `:mode` - `:confidential`, `:public`, or `:localhost`
    * `:redirect_uri` - the OAuth callback URL
    * `:scope` - the requsted scopes
    * `:client_id` - the URL of the published client metadata document
    * `:signing_key` - the JSON-encoded ES256 private JWK for `private_key_jwt` as string
    * `:client_name` - shown on the authorization consent screen
    * `:client_uri` - client home page
  """

  @default_request_ttl 600

  @enforce_keys [:store, :redirect_uri, :scope, :name, :mode]
  defstruct @enforce_keys ++
              [
                :client_id,
                :signing_key,
                :client_name,
                :client_uri,
                request_ttl: @default_request_ttl
              ]

  @type mode :: :confidential | :public | :localhost

  @type t :: %__MODULE__{
          store: module(),
          mode: mode(),
          client_id: String.t() | nil,
          redirect_uri: String.t(),
          scope: String.t(),
          signing_key: map() | nil,
          name: atom() | pid(),
          client_name: String.t() | nil,
          client_uri: String.t() | nil,
          request_ttl: non_neg_integer()
        }

  @modes [:confidential, :public, :localhost]

  @schema [
    store: [type: :atom, required: true],
    client_id: [type: :string, required: false],
    redirect_uri: [type: :string, required: true],
    scope: [type: :string, required: true],
    signing_key: [type: :string, required: false],
    name: [type: {:or, [:atom, :pid]}, required: true],
    client_name: [type: :string, required: false],
    client_uri: [type: :string, required: false],
    request_ttl: [type: :non_neg_integer, required: false, default: @default_request_ttl],
    mode: [type: {:in, @modes}, required: true]
  ]

  @doc false
  def build!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    mode = validated[:mode]

    struct!(
      __MODULE__,
      store: validated[:store],
      client_id: client_id!(mode, validated),
      redirect_uri: validated[:redirect_uri],
      scope: validated[:scope],
      signing_key: signing_key!(mode, validated),
      name: validated[:name],
      client_name: validated[:client_name],
      client_uri: validated[:client_uri],
      request_ttl: validated[:request_ttl],
      mode: mode
    )
  end

  def confidential?(%__MODULE__{mode: :confidential}), do: true
  def confidential?(%__MODULE__{}), do: false

  def localhost?(%__MODULE__{mode: :localhost}), do: true
  def localhost?(%__MODULE__{}), do: false

  defp client_id!(:localhost, validated) do
    if client_id = validated[:client_id] do
      error(
        :client_id,
        client_id,
        "invalid value for :client_id option, not allowed when mode is :localhost"
      )
    end

    "http://localhost?" <>
      URI.encode_query(redirect_uri: validated[:redirect_uri], scope: validated[:scope])
  end

  defp client_id!(_mode, validated) do
    if client_id = validated[:client_id] do
      client_id
    else
      error(
        :client_id,
        nil,
        "required :client_id option not found, received options: #{inspect(Keyword.keys(validated))}"
      )
    end
  end

  defp signing_key!(:confidential, validated) do
    signing_key = validated[:signing_key]

    if is_binary(signing_key) do
      Jason.decode!(signing_key)
    else
      error(
        :signing_key,
        nil,
        "required :signing_key option not found, received options: #{inspect(Keyword.keys(validated))}"
      )
    end
  end

  defp signing_key!(mode, validated) do
    if key = validated[:signing_key] do
      error(
        :signing_key,
        key,
        "invalid value for :signing_key option, not allowed when mode is #{inspect(mode)}"
      )
    end
  end

  defp error(key, value, message) do
    raise %NimbleOptions.ValidationError{key: key, value: value, message: message}
  end
end
