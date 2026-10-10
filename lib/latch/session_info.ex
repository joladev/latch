defmodule Latch.SessionInfo do
  @moduledoc """
  Metadata about a session, such as the `pds_endpoint`.
  """

  alias Latch.Session

  @enforce_keys [
    :did,
    :scope,
    :issuer,
    :pds_endpoint,
    :expires_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          scope: String.t(),
          issuer: String.t(),
          pds_endpoint: String.t(),
          expires_at: DateTime.t()
        }

  def from_session(%Session{} = session) do
    %__MODULE__{
      did: session.did,
      scope: session.scope,
      issuer: session.issuer,
      pds_endpoint: session.pds_endpoint,
      expires_at: session.expires_at
    }
  end
end
