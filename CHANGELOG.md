# CHANGELOG

## v0.5.0 (2026-08-02)

  * Breaking change: `client_id` and `redirect_uri` are replaced with `client_id_path`, `redirect_uri_path`, and `base_url_fun`, with the latter dynamically building the base URL, eg `fn -> MyAppWeb.Endpoint.url() end`.

## v0.4.0 (2026-08-01)

  * Breaking change: the 4th argument to `query` now takes `opts` instead of `params`, where `params` is one of the possible opts.
  * Introduce support for PDS proxying of requests, passing the `service` opt to the client calls.

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
