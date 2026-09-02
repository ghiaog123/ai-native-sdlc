# Specification: public API rate limiting

## Requirements

- Apply a fixed 120-request allowance per rolling 60-second window to all routes under `/v1/public`.
- Identify callers by API-key ID when a valid key is supplied; otherwise use a salted hash of the client IP.
- Return `429` before application work begins when the allowance is exhausted, with `Retry-After`, `RateLimit-Limit`, `RateLimit-Remaining`, and `RateLimit-Reset` headers.
- Increment a `public_api_rate_limit_rejections_total` metric labeled only by route template and identity type.
- If Redis is unavailable, allow the request, emit `public_api_rate_limit_store_error_total`, and log no key or raw IP value.

## Design

Gateway middleware derives an identity token, then performs an atomic Redis sorted-set sliding-window update with a 65-second TTL. The route template and identity token form the key. Middleware writes standard headers for accepted and rejected requests. A feature flag enables the middleware by route group; rollout starts at 10% of public traffic.

## Organization skill constraints

- Security: rate-limit keys use API-key IDs or HMAC-SHA-256 IP hashes with a server-held rotation secret; no raw identity value is logged.
- Compliance: hashed IP quota keys expire within 65 seconds and are not exported to analytics.
- Data: metrics use bounded route templates and identity type only, preventing high-cardinality identities.

## Flagged concerns

- The fail-open Redis behavior protects availability but could allow temporary abuse; API Platform owns the alert and outage review.
- IPv6 privacy addresses may change frequently; Security must approve whether they need a separate policy.

## Extension contract

- Extension: gateway middleware contract v1; input is request context, output is allow/deny plus rate-limit headers, and Redis errors produce allow plus an operational metric.
