defmodule Latch.Error.RefreshFailed do
  @moduledoc """
  	A token refresh was attempted and failed.

   `reason` is the underlying `Latch.Error.t()` that caused the refresh
   to fail, including transient and permanent errors.
  """

  defexception [:did, :reason]

  alias Latch.Error

  @type t :: %__MODULE__{did: String.t(), reason: Error.t()}

  @impl Exception
  def message(%__MODULE__{did: did, reason: reason}) do
    "token refresh failed for did #{inspect(did)}: #{Exception.message(reason)}"
  end
end
