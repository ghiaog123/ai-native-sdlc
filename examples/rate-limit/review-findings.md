# Review findings: public API rate limiting

Reviewer: sdlc-reviewer. Depth: Deep.
Round cap: 3.

## Round 1 — Plan — `a1b2c3d`

Passes run: Plan.

Scope: whole `plan.md`.

`.sdlc/rate-limit/plan.md:14 — Important — Proof names "unit tests for the middleware" without saying what they assert, so no test here would fail if the sliding window counted the wrong interval — name the assertion: a request at window boundary minus one second is counted, one at boundary plus one second is not`

`.sdlc/rate-limit/plan.md:6 — Minor — Files that change omits src/metrics/api.ts, which step 4 of Order of work edits; the artifact gate admits writes from this list, so implementation would be blocked at that step — add the file`

No additional Plan findings.

Verifier rejected: 1 — a claimed ordering defect between steps 2 and 3; step 3 does not read step 2's output, so the failure does not happen.

## Round 2 — Code — `e4f5a6b`

Passes run: Bugs, Security, Compliance.

Scope: whole change. First code round.

Already reported in an earlier round, not repeated here: 0.

`src/middleware/rateLimit.ts:84 — Important — the Redis key uses the raw API key, so a credential appears in Redis inspection and backup data — derive the key from the API-key ID or an HMAC digest before composing the Redis key — Response: fixed`

`src/middleware/rateLimit.ts:117 — Important — a rejected request omits RateLimit-Reset, so clients cannot determine when to retry and will retry aggressively — set RateLimit-Reset from the oldest in-window request before returning 429 — Response: fixed`

`src/metrics/api.ts:42 — Minor — the rejection metric labels the unbounded request path rather than its route template, creating a cardinality-based availability risk — label the metric with the router's normalized route template — Response: fixed`

`src/routes/public.ts:51 — Important — the route handler reads req.headers['x-forwarded-for'] without trusting the proxy chain, so a client can spoof its own identity; this change does not introduce the defect but makes it the rate-limit identity, turning a spoof into a bypass — set the framework's trust-proxy setting and read the derived client IP — Response: fixed`

<!-- Pre-existing, but a security finding: reported under Security at its real severity, and it blocks merge like any other. The tag would have changed who is answerable, never whether the change ships. -->

No additional Bugs, Security, or Compliance findings.

Verifier rejected: 2.

## Round 3 — Code — `b7c8d9e`

Passes run: Bugs, Security, Compliance.

Scope: diff from `e4f5a6b` to `b7c8d9e`.

Already reported in an earlier round, not repeated here: 3.

No findings.

Verifier rejected: 0.

## Pre-existing

| Finding | Where | Decision |
| --- | --- | --- |
| Client identity derived from an untrusted `x-forwarded-for` header | `src/routes/public.ts:51` | Fixed in this change — reported at `Important` under Security, since the change makes the spoofable header the rate-limit identity |

A pre-existing defect that is not a security finding would sit here with a backlog
reference or an accepted reason instead, and would not block the merge.

## Recurring

| Class | Changes seen in | Encoded as |
| --- | --- | --- |
| Metric labelled with a raw request path instead of its route template | `rate-limit`, `auth-throttle` | `CLAUDE.md` line under "Things Claude gets wrong": label metrics with the router's normalized route template; raw paths are unbounded cardinality |

## Round summary

| Round | Stage | Findings posted | Suppressed as duplicates | Verifier rejected |
| --- | --- | --- | --- | --- |
| 1 | Plan | 2 | 0 | 1 |
| 2 | Code | 4 | 0 | 2 |
| 3 | Code | 0 | 3 | 0 |
