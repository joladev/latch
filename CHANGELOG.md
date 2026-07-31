# CHANGELOG

## v0.3.0 (2026-07-31)

  * Stop following redirects on sensitive HTTP requests.
  * Add TID module with deterministic implementations.
  * Add NSID module for collection validation.
  * Add RecordKey module for rkey validation.
  * Add AtURI module for parsing and constructing at-uris.

## v0.2.0 (2026-07-26)

  * Introduce `Latch.Store.ETS` as a built-in `Store` implementation to make it easier to integrate.
  * Support `public` and `confidential` client modes.
  * Correctness fix: strip `:fragment` from `htu`.

## v0.1.0 (2026-07-21)

  * Full end to end implementation with `:confidential` mode.
