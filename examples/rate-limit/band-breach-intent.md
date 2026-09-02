# Intent: investigate public API rate-limit latency regression
Author: API Platform on-call. Status: draft.

## Breach report
At 2026-09-02 14:20 UTC, `public_api_p99_latency_ms` remained at 860 ms for 14 minutes after the rate-limit rollout reached 100%, crossing the tier-2 threshold of 700 ms. Error rate stayed below 0.4%. Trace samples show the added Redis quota command accounts for 390–510 ms on affected requests. The 14:05 UTC deployment is the only deploy in the breach window.

## Problem
Public API customers experience latency above the approved p99 band after rate-limit enforcement, even though requests succeed.

## Proposed outcome
Identify why quota-store latency is elevated and produce a safe, measured change that returns public API p99 below 400 ms without weakening the approved 120-request limit.

## Affected users and systems
Public API consumers, gateway middleware, Redis quota cluster, API Platform dashboards, and on-call incident response are affected.

## Constraints
Do not change production enforcement, Redis topology, or feature-flag state without human incident authorization. Preserve identity hashing, header behavior, and the fail-open outage policy. Use read-only traces, Redis metrics, and deployment history during diagnosis.

## Open questions
Is the regression caused by cross-region Redis routing, connection-pool saturation, or the sorted-set operation itself? Does only one availability zone show the elevated Redis command time?

Confidence: medium — deployment timing and trace spans strongly associate the latency with the quota call, but they do not yet distinguish network routing from Redis saturation.

Evidence: dashboard window 14:20–14:34 UTC; trace samples for `/v1/public/search`; Redis command-latency dashboard; deployment record at 14:05 UTC.
