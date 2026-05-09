# Pushback Review: Registry Publish Flag Design

**Date:** 2026-05-09
**Spec:** `docs/specs/2026-05-09-registry-publish-flag-design.md`
**Commit:** accf6c5

## Source Control Conflicts

### [1] container-tag "latest" default conflicts with recent commit rationale

- **Commit:** 5bc316b (PR #410, merged same day)
- **What the spec assumed:** `container-tag` can default to `"latest"` when made optional.
- **What actually changed:** Commit 5bc316b made `container-tag` required, with the rationale: "The default of 'latest' was never valid — no language-specific dev container image publishes a :latest tag."
- **Why this matters:** The spec proposes reverting `container-tag` to optional with `default: "latest"`. This is safe when paired with `language: base` (since `dev-base:latest` exists), but the commit's concern about language-specific images remains valid.
- **Resolution:** Added a note to the spec clarifying that `latest` is only valid with `language: base`, and added a validation step to fail fast when the pairing is invalid.

## Issues Reviewed

### [2] No validation that language and container-tag are paired correctly
- **Category:** Omission
- **Severity:** Moderate
- **Issue:** A caller could pass `language: python` without a `container-tag` and get `dev-python:latest`, which doesn't exist. This would fail at container pull time with a cryptic image-not-found error.
- **Resolution:** Added a validation step to the spec that fails fast with a clear error if `language != 'base'` and `container-tag == 'latest'`.

### [3] Rollout window risk between standard-actions merge and fleet updates
- **Category:** Omission
- **Severity:** Moderate
- **Issue:** Between merging the workflow change and updating fleet callers, any release would silently skip registry publishing because `registry-publish` defaults to `false`.
- **Resolution:** No spec change. The fleet is frozen — no releases will be triggered during this window. The fleet is managed as a unit, not independently.

### [4] Existing implementation plan needs reconciliation
- **Category:** Omission
- **Severity:** Minor
- **Issue:** The existing plan at `docs/plans/2026-05-09-registry-publish-flag.md` doesn't include the validation step and has incorrect fleet table entries (standard-tooling and ai-research-methodology listed as `registry-publish: true`).
- **Resolution:** No spec change. The plan will be regenerated from the updated spec during the transition to implementation.

### [5] registry-publish: true without a language silently does nothing
- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** If a caller passes `registry-publish: true` but omits `language` (getting the `base` default), the ecosystem command derivation hits the wildcard fallback — no build command, no publish command. The registry-publish steps silently do nothing.
- **Resolution:** Extended the validation step to also fail fast if `registry-publish == true` and `language == 'base'`.

## Unresolved Issues

None — all issues were addressed.

## Summary

- **Issues found:** 5 (1 source control conflict, 4 from critique)
- **Issues resolved:** 5
- **Spec status:** Ready for implementation
