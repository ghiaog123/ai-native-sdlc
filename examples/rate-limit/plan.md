# Plan: public API rate limiting (from intent.md 2026-09-02)

## Files that change

- `src/middleware/rateLimit.ts` — identity derivation, Redis sliding-window check, and response headers.
- `src/routes/public.ts` — install middleware behind the public-route feature flag.
- `src/config/rateLimit.ts` — quota, window, Redis prefix, and rollout flag settings.
- `src/metrics/api.ts` — bounded rejection and store-error metrics.
- `test/middleware/rateLimit.test.ts` — quota, headers, identity, Redis failure, and concurrency coverage.
- `docs/public-api.md` — published limits and `429` response contract.

## Order of work

1. Add validated rate-limit configuration and the feature flag with a disabled default.
2. Implement the atomic Redis sliding-window operation and identity hashing without logging identity values.
3. Add middleware and standard response headers, then attach it only to `/v1/public`.
4. Add metrics and structured, redacted operational logs.
5. Add unit and integration tests, then publish the API documentation.
6. Enable the flag for 10% of public traffic after human review of dashboards and rollback instructions.

## Risks

Redis outage can fail open and reduce abuse protection. A bad route template can create high-cardinality metrics. Proxy configuration can make source IP identity unreliable. A feature-flag rollback must remove enforcement without changing existing authentication.

## Proof

Tests prove the 121st request is rejected, headers are correct, different API keys have independent quotas, raw IP and key values never reach logs or metrics, Redis failures allow requests and increment the store-error metric, and concurrent requests do not exceed the allowance. A staging load test verifies public-route p99 remains below 400 ms.

## Deviations
None.
