# Intent: public API rate limiting
Author: API Platform. Status: accepted.

## Problem
Anonymous clients can issue unlimited requests to public API endpoints. A single noisy client can exhaust application workers and make legitimate customer requests slow or unavailable.

## Proposed outcome
Each public API client receives a clear, predictable request allowance. Requests beyond that allowance return `429 Too Many Requests` with reset metadata, while normal customer traffic remains within the latency SLO.

## Affected users and systems
Public API consumers, API gateway middleware, Redis quota storage, application metrics, support runbooks, and on-call responders are affected.

## Constraints
Use an API-key identity when present and source IP otherwise. Do not persist raw IP addresses longer than the quota window. Preserve existing authenticated endpoint behavior during rollout. The first release must support 120 requests per minute per identity and must fail open only when Redis is unavailable, with an alert.

## Open questions
Should enterprise API keys receive a documented higher limit in the first release, or follow the same 120 requests per minute limit?
