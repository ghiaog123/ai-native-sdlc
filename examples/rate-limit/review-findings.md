# Review findings: public API rate limiting

Passes run: Bugs, Security, Compliance.

`src/middleware/rateLimit.ts:84 — Important — the Redis key uses the raw API key, allowing a credential to appear in Redis inspection and backup data — derive the key from the API-key ID or an HMAC digest before composing the Redis key`

`src/middleware/rateLimit.ts:117 — Important — a rejected request omits RateLimit-Reset, so clients cannot determine when to retry and will retry aggressively — set RateLimit-Reset from the oldest in-window request before returning 429`

`src/metrics/api.ts:42 — Minor — the rejection metric labels the unbounded request path rather than its route template, creating a cardinality-based availability risk — label the metric with the router's normalized route template`

No additional Bugs, Security, or Compliance findings.
