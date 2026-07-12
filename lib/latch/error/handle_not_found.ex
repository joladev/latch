defmodule Latch.Error.HandleNotFound do
  @moduledoc """
  	A handle could not be resolved to a DID during `authorize/2`.

  ## `reason` values

    * `:invalid_handle` - the handle was malformed
    * `:handle_not_found` - DNS and well-known lookups returned nothing
    * `:ambiguous_dns` - multiple distinct DIDs at one handle
    * `:unsupported_did_method` - the resolved DID method is not implemented
  """

  defexception [:handle, :reason]

  @type t :: %__MODULE__{handle: String.t() | nil, reason: atom()}

  @impl Exception
  def message(%__MODULE__{handle: handle, reason: reason}) do
    "could not resolve handle #{inspect(handle)}: #{inspect(reason)}"
  end
end
