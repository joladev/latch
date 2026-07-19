defmodule Latch.Request do
  @moduledoc """
  An in-flight atproto OAuth authorization request, keyed by `state`.

  Latch stores this via `Latch.Store` at the start of a login
  (`authorize/2`) and consumes it, single use, in `callback/2`.
  """

  @derive {Inspect, except: [:dpop_key]}
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
          dpop_key: map()
        }
end
