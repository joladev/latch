defmodule Latch.Request do
  @moduledoc false

  @enforce_keys [
    :state,
    :did,
    :handle,
    :pds_endpoint,
    :issuer,
    :token_endpoint,
    :pkce_verifier,
    :dpop_key
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          state: String.t(),
          did: String.t(),
          handle: String.t(),
          pds_endpoint: String.t(),
          issuer: String.t(),
          token_endpoint: String.t(),
          pkce_verifier: String.t(),
          dpop_key: JOSE.JWK.t()
        }
end
