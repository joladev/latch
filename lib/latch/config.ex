defmodule Latch.Config do
  @moduledoc """
  The internal configuration that drives the library.

  ## Fields
    * `:store` - a module implementing `Latch.Store`
    * `:name` - the name of the Latch instance
    * `:mode` - `:confidential`, `:public`, or `:localhost`
    * `:redirect_uri_path` - the OAuth callback path
    * `:scope` - the requsted scopes
    * `:client_id_path` - the path of the published client metadata document
    * `:signing_key` - the JSON-encoded ES256 private JWK for `private_key_jwt` as string
    * `:client_name` - shown on the authorization consent screen
    * `:client_uri` - client home page
    * `:base_url_fun` - function to build the base URL for `redirect_uri` and `client_id`, because the host is frequently only known at runtime.
    * `:finch` - an optional Finch override to the Req client, refer to https://req.hexdocs.pm/Req.html#new/2 for the full set of options
  """

  @default_request_ttl 600

  @enforce_keys [:store, :redirect_uri_path, :scope, :name, :mode, :base_url_fun]
  defstruct @enforce_keys ++
              [
                :client_id_path,
                :signing_key,
                :client_name,
                :client_uri,
                :pool,
                request_ttl: @default_request_ttl
              ]

  @type mode :: :confidential | :public | :localhost

  @type t :: %__MODULE__{
          store: module(),
          mode: mode(),
          client_id_path: String.t() | nil,
          redirect_uri_path: String.t(),
          base_url_fun: (-> String.t()),
          scope: String.t(),
          signing_key: map() | nil,
          name: atom() | pid(),
          client_name: String.t() | nil,
          client_uri: String.t() | nil,
          request_ttl: non_neg_integer(),
          pool: keyword()
        }

  @modes [:confidential, :public, :localhost]

  @input_schema [
    store: [type: :atom, required: true],
    client_id_path: [type: :string, required: false],
    redirect_uri_path: [type: :string, required: true],
    base_url_fun: [type: {:fun, 0}, required: true],
    scope: [type: :string, required: true],
    signing_key: [type: :string, required: false],
    name: [type: {:or, [:atom, :pid]}, required: true],
    client_name: [type: :string, required: false],
    client_uri: [type: :string, required: false],
    request_ttl: [type: :non_neg_integer, required: false, default: @default_request_ttl],
    mode: [type: {:in, @modes}, required: true],
    finch: [type: :keyword_list, required: false]
  ]

  @doc false
  def build!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @input_schema)
    mode = validated[:mode]

    struct!(
      __MODULE__,
      store: validated[:store],
      client_id_path: client_id_path!(mode, validated),
      redirect_uri_path: validated[:redirect_uri_path],
      base_url_fun: validated[:base_url_fun],
      scope: validated[:scope],
      signing_key: signing_key!(mode, validated),
      name: validated[:name],
      client_name: validated[:client_name],
      client_uri: validated[:client_uri],
      request_ttl: validated[:request_ttl],
      mode: mode,
      pool: configure_pool(validated[:finch], validated[:name])
    )
  end

  def confidential?(%__MODULE__{mode: :confidential}), do: true
  def confidential?(%__MODULE__{}), do: false

  def localhost?(%__MODULE__{mode: :localhost}), do: true
  def localhost?(%__MODULE__{}), do: false

  def client_id(%__MODULE__{
        mode: :localhost,
        redirect_uri_path: redirect_uri_path,
        scope: scope,
        base_url_fun: base_url_fun
      }) do
    redirect_uri = base_url_fun.() <> redirect_uri_path
    "http://localhost?" <> URI.encode_query(redirect_uri: redirect_uri, scope: scope)
  end

  def client_id(%__MODULE{client_id_path: client_id_path, base_url_fun: base_url_fun}) do
    base_url_fun.() <> client_id_path
  end

  def redirect_uri(%__MODULE__{redirect_uri_path: redirect_uri_path, base_url_fun: base_url_fun}) do
    base_url_fun.() <> redirect_uri_path
  end

  defp client_id_path!(:localhost, validated) do
    if client_id_path = validated[:client_id_path] do
      error(
        :client_id_path,
        client_id_path,
        "invalid value for :client_id_path option, not allowed when mode is :localhost"
      )
    end
  end

  defp client_id_path!(_mode, validated) do
    if client_id_path = validated[:client_id_path] do
      client_id_path
    else
      error(
        :client_id_path,
        nil,
        "required :client_id_path option not found, received options: #{inspect(Keyword.keys(validated))}"
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

  defp configure_pool(nil, base) do
    [name: Latch.Pool.name(base)]
  end

  defp configure_pool(finch, _base) do
    finch
  end
end
