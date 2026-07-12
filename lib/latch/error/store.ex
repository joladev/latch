defmodule Latch.Error.Store do
  @moduledoc """
  The caller's `Latch.Store` implementation returned an error. The
  specific callback is in the `action` field.

  ## `action` values

    * `:fetch_session`
    * `:put_session`
    * `:delete_session`
    * `:update_session`
    * `:take_request`
    * `:put_request`
    * `:delete_expired_requests`
  """

  defexception [:action, :did, :reason]

  @type action ::
          :fetch_session
          | :put_session
          | :delete_session
          | :update_session
          | :take_request
          | :put_request
          | :delete_expired_requests

  @type t :: %__MODULE__{action: action(), did: String.t() | nil, reason: term() | nil}

  @impl Exception
  def message(%__MODULE__{action: action, did: did, reason: reason}) do
    "store #{inspect(action)} failed for #{inspect(did)}: #{inspect(reason)}"
  end
end
