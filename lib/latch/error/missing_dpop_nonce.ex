defmodule Latch.Error.MissingDPoPNonce do
  @moduledoc """
  The server responded with `use_dpop_nonce` but did not provide a
  header to retry with. This is a server side issue.
  """

  defexception [:endpoint]

  @type t :: %__MODULE__{}

  @impl Exception
  def message(%__MODULE__{}) do
    "server demanded a DPoP nonce but provided none"
  end
end
