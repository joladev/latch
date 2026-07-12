defmodule Latch.Error.InvalidResponse do
  @moduledoc """
  A server response was structurally invalid, including bad JSON or a
  missing or malformed required field.

  ## `reason` values
    * `:invalid_json`
    * `:unexpected_response`
    * `{:http_status, status}`
    * `{:missing, field}`
    * `{:invalid, field}`
  """

  defexception [:reason]

  @type reason ::
          :invalid_json
          | :unexpected_response
          | {:http_status, pos_integer()}
          | {:missing, String.t()}
          | {:invalid, String.t()}

  @type t :: %__MODULE__{reason: reason}

  @impl Exception
  def message(%__MODULE__{reason: reason}) do
    "invalid server response: #{inspect(reason)}"
  end
end
