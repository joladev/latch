defmodule Latch.Error.XRPC do
  @moduledoc """
  The PDS returned a non-2xx XRPC response.
  """

  defexception [:status, :body]

  @type t :: %__MODULE__{status: pos_integer(), body: map()}

  @impl Exception
  def message(%__MODULE__{status: status}) do
    "XRPC error: HTTP #{status}"
  end
end
