# Plan: [feature name] (from intent.md [date])

<!--
Write this only after the intent and specification are accepted, or on the fast path.
Commit it before source-code writes.

A fast-path change — one entering at Build with no intent.md and no spec.md — adds a
section with the heading "## Fast path" above "Files that change", holding the name of
the person who declared the change low-risk, their reason, and the result of the
sensitive-path check. That heading is what the artifact gate reads, so do not add it to
an ordinary plan: it closes every sensitive path for as long as the plan is active. See
the sdlc-build skill for the exact wording.
-->
## Files that change
[list of affected files]

## Order of work
[numbered steps]

## Risks
[potential issues]

## Proof
[test coverage description]

## Deviations
<!-- Record accepted departures from this plan as they occur; leave `None.` when there are none. -->
None.
