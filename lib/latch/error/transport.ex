defmodule Latch.Error.Transport do
  @moduledoc """
  An HTTP request failed at the transport layer.
  """

  defexception [:reason]

  @type t :: %__MODULE__{reason: Exception.t()}

  @impl Exception
  def message(%__MODULE__{reason: reason}) do
    "HTTP transport failed: #{Exception.message(reason)}"
  end
end
