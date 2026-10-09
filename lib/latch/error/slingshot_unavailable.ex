defmodule Latch.Error.SlingshotUnavailable do
  @moduledoc """
  An request to Slingshot failed for an unexpected error.
  """

  defexception [:error]

  @type t :: %__MODULE__{error: Exception.t()}

  @impl Exception
  def message(%__MODULE__{error: error}) do
    "Slingshot error: #{Exception.message(error)}"
  end
end
