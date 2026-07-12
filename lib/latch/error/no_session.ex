defmodule Latch.Error.NoSession do
  @moduledoc """
  No stored session exists for the given DID.
  """

  defexception [:did]

  @type t :: %__MODULE__{did: String.t()}

  @impl Exception
  def message(%__MODULE__{did: did}) do
    "no session for did #{inspect(did)}"
  end
end
