defmodule Latch.Error do
  @moduledoc """
  Errors returned by the public `Latch` and `Latch.Client` API.

  Every public function that can fail returns `{:error, Latch.Error.t()}`.
  Each error is an exception struct so callers can eitehr pattern match on
  its fields or `raise/1` it directly.
  """

  alias Latch.Error.Discovery
  alias Latch.Error.HandleNotFound
  alias Latch.Error.IdentityMismatch
  alias Latch.Error.InvalidResponse
  alias Latch.Error.MissingDPoPNonce
  alias Latch.Error.NoSession
  alias Latch.Error.OAuth
  alias Latch.Error.RefreshFailed
  alias Latch.Error.SecurityViolation
  alias Latch.Error.Store
  alias Latch.Error.Transport
  alias Latch.Error.XRPC

  @type t ::
          Discovery.t()
          | HandleNotFound.t()
          | IdentityMismatch.t()
          | InvalidResponse.t()
          | MissingDPoPNonce.t()
          | NoSession.t()
          | OAuth.t()
          | RefreshFailed.t()
          | SecurityViolation.t()
          | Store.t()
          | Transport.t()
          | XRPC.t()
end
