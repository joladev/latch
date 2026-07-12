defmodule Latch.Error.IdentityMismatch do
  @moduledoc """
  A handle reoslved to a DID, but the DID document does not read back to it,
  or it lacks a usable PDS endpoint.

  ## `reason` values

    * `:handle_mismatch` - the DID document claims a different handle
    * `:invalid_did` - the DID could not be parsed
    * `:no_pds` - the DID document has no PDS service entry
    * `:invalid_pds_endpoint` - the PDS service target is not a valid URL
    * `:did_mismatch`
  """

  defexception [:handle, :reason]

  @type t :: %__MODULE__{handle: String.t() | nil, reason: atom()}

  @impl Exception
  def message(%__MODULE__{handle: handle, reason: reason}) do
    "identity verification failed for handle #{inspect(handle)} #{inspect(reason)}"
  end
end
