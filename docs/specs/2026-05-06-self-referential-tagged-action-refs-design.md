# Self-Referential Tagged Action Refs

**Issue:** [#343](https://github.com/wphillipmoore/standard-actions/issues/343)
**Date:** 2026-05-06
**Scope:** Wave 1 — CI gate workflows only (docs and publish are wave 2)

## Problem

Reusable CI workflows in standard-actions reference composite actions
using either `./actions/...` (relative paths) or
`wphillipmoore/standard-actions/...@develop` (remote refs pinned to
develop). Both break for consumer repos:

- `./actions/...` resolves relative to the caller's checkout, not
  standard-actions — consumers get "Can't find action.yml" errors.
- `@develop` resolves without errors but points to whatever is on HEAD
  of develop at runtime, not the tagged release the consumer pinned to.

## Design Principle

Source code uses relative paths (`./actions/...`) so that
standard-actions' own CI on feature branches tests the actual action
code in that branch — true self-referencing during development. At
publish time, the freeze step rewrites these to fully-qualified tagged
refs so consumers get a consistent, immutable snapshot.

## Changes

### 1. Source code: convert `@develop` refs to `./` in CI workflows

Convert all remaining remote `@develop` references in CI gate workflows
to relative `./actions/...` paths. Files already using `./` are left
unchanged.

**`ci-security.yml`** (4 lines change):
| Line | Before | After |
|------|--------|-------|
| 43 | `wphillipmoore/standard-actions/actions/standards-compliance@develop` | `./actions/standards-compliance` |
| 56 | `wphillipmoore/standard-actions/actions/security/codeql@develop` | `./actions/security/codeql` |
| 71 | `wphillipmoore/standard-actions/actions/security/trivy@develop` | `./actions/security/trivy` |
| 87 | `wphillipmoore/standard-actions/actions/security/semgrep@develop` | `./actions/security/semgrep` |

**`ci-release.yml`** (1 line changes):
| Line | Before | After |
|------|--------|-------|
| 29 | `wphillipmoore/standard-actions/actions/release-gates/version-divergence@develop` | `./actions/release-gates/version-divergence` |

**No changes needed:**
- `ci-quality.yml` — already uses `./actions/setup/standard-tooling`
- `ci-test.yml` — already uses `./actions/setup/standard-tooling`
- `ci-audit.yml` — already uses `./actions/setup/standard-tooling`
- `actions/standards-compliance/action.yml` — already uses
  `./actions/setup/standard-tooling`

**Out of scope (wave 2):**
- `publish.yml` — keeps `@develop` refs to its own composite actions
- `publish-release.yml` — keeps `@develop` refs
- `docs.yml` — keeps `./actions/docs-deploy` (push-triggered, not
  reusable)

### 2. Freeze step: handle `./actions/` pattern

Update the `freeze-internal-refs` step in `publish.yml` (lines 61-83)
to add a second sed pass for the `./actions/` pattern.

**Two sed passes per file, no grep guard** (seds are idempotent no-ops
on files without matches):

1. **Pass 1 (new):** `./actions/X` →
   `wphillipmoore/standard-actions/actions/X@<tag>`
   ```
   sed -E "s|\./actions/([^[:space:]]+)|wphillipmoore/standard-actions/actions/\1@${RELEASE_TAG}|g"
   ```

2. **Pass 2 (existing):** `...@develop` → `...@<tag>`
   ```
   sed -E "s|(wphillipmoore/standard-actions/[^@[:space:]]+)@develop|\1@${RELEASE_TAG}|g"
   ```

Order matters: pass 1 runs first so all `./` refs become remote refs
before pass 2 handles any remaining `@develop` refs (from publish
workflows, unchanged until wave 2).

The grep guard that currently decides whether to process each file is
removed. The seds run unconditionally on every YAML file found — if a
file has no matches, the sed is a no-op.

After all seds run, `git diff --quiet` determines whether anything
changed. If so, the modified files are staged and committed. If not,
the step is a no-op. This replaces the current grep-based rewrote
counter.

### 3. Validation step

A new workflow step after the freeze commit validates that no unfrozen
internal refs survived in the working tree. This is a separate step so
it appears as its own check in the GitHub Actions UI.

Two patterns are checked across all YAML files in `.github/workflows/`
and `actions/`:

1. No `./actions/` remains (unfrozen relative refs)
2. No `wphillipmoore/standard-actions/...@develop` remains (unfrozen
   remote refs)

If either pattern is found, the step fails with a clear error message
listing the offending files and lines. The publish workflow stops before
tagging.

## Files Modified

| File | Change |
|------|--------|
| `.github/workflows/ci-security.yml` | 4 `uses:` lines: `@develop` → `./` |
| `.github/workflows/ci-release.yml` | 1 `uses:` line: `@develop` → `./` |
| `.github/workflows/publish.yml` | Freeze step updated + validation step added |

## What This Enables

After this change, consumer repos pinned to a tag (e.g. `@v1.5.5`) get
workflows whose internal composite action references all point to the
same tag — a consistent, immutable snapshot. This unblocks Phase 3 of
the CI workflow reset rollout and fixes the consumer repo failures
(e.g. standard-tooling-plugin PR #253).
