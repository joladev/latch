# CHANGELOG

## v0.8.0 (2026-09-04)

  * Wrap token refreshes in an unlinked Task to ensure it always finishes, even when the caller exits.
  * Introduces SpaceURI building and parsing, for the new permissioned data spaces.
  * Adds `TID.to_unix/1`, `TID.to_datetime/1`, and `TID.to_datetime!/1` for extracting timestamps from TIDs.
  * Exposes `pds_endpoint` in the OAuth callback result, for consistency.

## v0.7.0 (2026-08-23)

### Improvements

  * Exposes `Latch.resolve_handle/2` and `Latch.resolve_did/2` for validation and verification, as well as looking up handle, DID, and PDS endpoint.
  * Make PLC endpoint URL configurable with the new `plc_directory` option, useful for local development.

## v0.6.0 (2026-08-22)

### Breaking changes

  * Require Req 0.7 or higher

### Improvements

 * Latch now defines its own Finch pool, with the option to override it.
 * Configure `receive_timeout` on `Latch.query`, `Latch.procedure` and `Latch.upload_blob`.

## v0.5.0 (2026-08-02)

  * Breaking change: `client_id` and `redirect_uri` are replaced with `client_id_path`, `redirect_uri_path`, and `base_url_fun`, with the latter dynamically building the base URL, eg `&MyAppWeb.Endpoint.url/0`.

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
