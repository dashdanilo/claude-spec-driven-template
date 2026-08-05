---
paths: "docs/decisions/**"
---

# ADRs are append-only

An Architecture Decision Record is a historical record, not a living document.

- Never rewrite the decision of an **accepted** ADR. If the decision changes, write a **new** ADR that supersedes it, and mark the old one `Superseded by ADR-NNNN`.
- Decisions accumulate — the trail of why we changed our mind is the value.
- A new ADR states **Context → Decision → Consequences** and a status (`Proposed` → `Accepted` → `Superseded`).
- Fixing a typo or adding a link is fine; changing what was decided is not.
