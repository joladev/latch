defmodule Latch.Store do
  @moduledoc """
  Storage backend for in-flight OAuth requests and long-lived sessions.

  Implement this behavior in your app. The library is storage-agnostic.
  It hands you plains tructs and expects you to persist them however you
  like (Ecto, Redis, ETS, ...). The library never sees encryption or the
  database, that's your concerns.

  Requests are keyed by the OAuth `state`.
  Sessions are keyed by the user's DID.
  """

  alias Latch.Request
  alias Latch.Session

  @type state :: binary()
  @type did :: binary()

  @type reason :: :not_found | :backend_error
  @type store_error :: {:error, reason()}

  @doc """
  Store an inflight request under `state` for at least `ttl_seconds`.
  """
  @callback put_request(state(), Request.t(), ttl_seconds :: pos_integer()) ::
              :ok | store_error()

  @doc """
  Atomically fetch and remove the request for `state`.

  Single use. Must be consumable exactly once, even under concurrency.
  Return `{:error, :not_found}` if used or non-existant.
  """
  @callback take_request(state()) :: {:ok, Request.t()} | store_error()

  @doc """
  Remove requests older than `max_age_seconds`.

  Optional housekeeping: return the count deleted. `:ok` also fine.
  """
  @callback delete_expired_requests(max_age_seconds :: pos_integer()) :: non_neg_integer() | :ok

  @doc """
  Fetch the session for `did`.
  """
  @callback fetch_session(did()) :: {:ok, Session.t()} | store_error()

  @doc """
  Insert or replace session for `did`.
  """
  @callback put_session(did(), Session.t()) :: :ok | store_error()

  @doc """
  Delete the session for `did`. Return `:ok` even if missing.
  """
  @callback delete_session(did()) :: :ok | store_error()

  @doc """
  Run `fun` against the session for `did` under an exclusive lock, within
  an atomic transaction. Rotating refresh tokens are single use, so two
  concurrent refreshes must run in serial.

  Use `FOR UPDATE` or CAS to make atomic.

  - `{:ok, new_session}` persists `new_session` inside the same transaction and returns it.
  - `{:error, reason}` rolled back, reason propagated.

  `{:error, :not_found}` if no session exists for `did`.
  """
  @callback update_session(did(), (Session.t() -> {:ok, Session.t()} | {:error, term()})) ::
              {:ok, Session.t()} | store_error()
end
