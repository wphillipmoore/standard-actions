# Pushback Review: Rationalize actions/ namespace design

**Date:** 2026-05-11
**Spec:** `docs/specs/2026-05-11-rationalize-actions-namespace-design.md`
**Commit:** f6bb81d

## Source Control Conflicts

None — no conflicts with recent changes. The spec was written after #453
(workflow extraction) landed and correctly accounts for the new composite
actions.

## Issues Reviewed

### [1] Two action-to-action references missing from reference tables
- **Category:** omissions
- **Severity:** serious
- **Issue:** The "Workflow reference updates" section only covered `uses:`
  paths in workflow files. Two composite actions also reference other
  actions: `standards-compliance/action.yml` uses
  `./actions/setup/standard-tooling` (local ref), and
  `registry-publish/action.yml` uses
  `wphillipmoore/standard-actions/actions/security/trivy@develop` (remote
  ref). Both would cause CI failures if missed during implementation.
- **Resolution:** Added an "Action-to-action reference updates" subsection
  with both references. Renamed the parent section from "Workflow reference
  updates" to "Reference updates."

### [2] `python/setup` is dead code, contradicts consumption model
- **Category:** ambiguity
- **Severity:** serious
- **Issue:** `actions/python/setup/` is not referenced by any workflow or
  action in this repo. The spec included it in the move table without
  noting this. Either it was dead code (should be removed) or it was
  consumed directly by client repos (contradicting the spec's claim that
  actions are internal-only). No other unreferenced actions were found.
- **Resolution:** Confirmed dead code — the action was phased out over
  time. Removed from the move table and directory structure. Added as a
  deletion step in the migration strategy. Updated MkDocs doc rename table
  to delete rather than rename the corresponding page.

### [3] Standard-tooling reference count wrong (7 vs 8)
- **Category:** contradictions
- **Severity:** moderate
- **Issue:** The spec said `./actions/setup/standard-tooling` appears in
  "seven workflows" but `ci-security.yml` was missing from the list,
  making the actual count eight.
- **Resolution:** Added `ci-security.yml` to the list and corrected the
  count to eight.

### [4] freeze-internal-refs concern is already a non-issue
- **Category:** ambiguity
- **Severity:** minor
- **Issue:** The spec said the freeze action's path-matching logic "must
  be verified" for deeper paths. The sed pattern
  (`\./actions/([^[:space:]]+)`) captures any depth — this was not an open
  question but read like one, creating ambiguity for the implementer.
- **Resolution:** Replaced hedging language with a definitive statement
  confirming the regex handles arbitrary depth. Kept a note to confirm
  with a test during implementation.

## Summary

- **Issues found:** 4
- **Issues resolved:** 4
- **Unresolved:** 0
- **Spec status:** ready for implementation
