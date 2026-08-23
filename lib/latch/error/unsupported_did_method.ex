defmodule Latch.Error.UnsupportedDIDMethod do
  @moduledoc """
  Only `did:web` and `did:plc` are supported methods.
  """

  defexception [:did]

  @type t :: %__MODULE__{did: String.t()}

  @impl Exception
  def message(%__MODULE__{did: did}) do
    "Unsupported DID method: #{did}"
  end
end
