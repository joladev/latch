defmodule Latch.Error.Discovery do
  @moduledoc """
  Authorization-server discovery failed for a PDS.

  ## `reason` values

    * `:no_authorization_server` - the PDS exposes no authorization server
    * `:resource_mismatch` - the PRM `resource` is not the PDS URL
    * `:issuer_mismatch` - the AS metadata issuer is not the discovered URL
    * `{:missing_metadata field}` - a required AS metadata field is missing
    * `{:invalid_metadata, field}` - a required AS metadata field has invalid value
  """

  defexception [:pds_endpoint, :reason]

  @type t :: %__MODULE__{pds_endpoint: String.t() | nil, reason: atom() | {atom(), String.t()}}

  @impl Exception
  def message(%__MODULE__{pds_endpoint: pds, reason: reason}) do
    "discovery failed for #{inspect(pds)}: #{inspect(reason)}"
  end
end
