# AI-native SDLC example: public API rate limiting

This worked change follows the loop from a customer problem through operational learning.

1. **Plan** — [intent.md](rate-limit/intent.md) describes why anonymous clients can overwhelm the public API and the desired customer outcome.
2. **Design** — [spec.md](rate-limit/spec.md) turns that intent into endpoint, identity, storage, and security requirements.
3. **Build** — [plan.md](rate-limit/plan.md) lists the implementation sequence, risks, and proof before code is written.
4. **Review** — the project reviewer runs Bugs, Security, and Compliance passes against the accepted artifacts.
5. **Deploy** — [review-findings.md](rate-limit/review-findings.md) shows actionable review output that must be resolved or accepted by a human before release.
6. **Maintain** — [band-breach-intent.md](rate-limit/band-breach-intent.md) shows a p99 breach becoming a new intent instead of an untracked production change.

The artifacts are deliberately specific: they document one plausible public API feature, not blanks to be filled in.
