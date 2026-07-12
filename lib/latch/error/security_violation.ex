defmodule Latch.Error.SecurityViolation do
  @moduledoc """
  An integrity check required by the atproto OAuth spec failed. A caller must
  not treat the user as logged in when one of these is returned.

  ## `reason` values
    * `:state_mismatch` - the callback `state` does not match the in-flight request
    * `:issuer_mismatch` - the callback `iss` does not match the discovered issuer
    * `:did_mismatch` - the token response `sub` does not match resolved DID
  """

  defexception [:reason]

  @type t :: %__MODULE__{
          reason: :state_mismatch | :issuer_mismatch | :did_mismatch
        }

  @impl Exception
  def message(%__MODULE__{reason: :state_mismatch}), do: "OAuth state mismatch"
  def message(%__MODULE__{reason: :issuer_mismatch}), do: "OAuth issuer mismatch"
  def message(%__MODULE__{reason: :did_mismatch}), do: "token sub does not match the resolved DID"
end
