defmodule Latch.RecordKey do
  @moduledoc """
  Record keys have a defined set of allowed shapes: TID, NSID, `literal:<value>`, and `any`.

  https://atproto.com/specs/record-key
  """

  @regex ~r/^[A-Za-z0-9._:~-]{1,512}$/

  @doc """
  Validates record key syntax according to the spec.

  From the spec:
  * the allowed characters are alphanumeric (A-Za-z0-9), period, dash, underscore, colon, or tilde (.-_:~)
  * must have at least 1 and at most 512 characters
  * the specific record key values . and .. are not allowed
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(key) when is_binary(key) do
    key not in [".", ".."] and String.match?(key, @regex)
  end
end
