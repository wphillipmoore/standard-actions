# Semgrep Ruleset Expansion

**Issue:** #303
**Date:** 2026-05-04
**Status:** Approved

## Goal

Expand the Semgrep composite action's security coverage by adding `p/ci` to the
base config and auto-detecting repo content to enable `p/dockerfile` and
`p/github-actions` rulesets without any configuration from consuming repos.

## Background

The Semgrep action (`actions/security/semgrep/action.yml`) runs with a fixed
base config of `p/security-audit` and `p/secrets`, plus a conditional
`p/$LANGUAGE` when the language-specific ruleset exists in the registry. Issue
Issue #303 identified several high-value rulesets that are not being used — most
notably `p/ci` (147 CI pipeline security rules), `p/dockerfile` (7 Dockerfile
best-practice rules), and `p/github-actions` (3 Actions injection rules).

The `ci-quality.yml` workflow already auto-detects file types to run the
appropriate linter (hadolint for Dockerfiles, shellcheck for shell scripts,
actionlint for workflow files). The Semgrep action should follow the same
pattern: detect what's in the repo and scan it accordingly.

## Design

### Base config change

Add `p/ci` to the hardcoded base config string. This ruleset covers CI pipeline
security (injection, secrets in workflows, unsafe patterns) and applies to all
repos. The base config becomes:

```text
p/ci p/security-audit p/secrets
```

### Auto-detection

After the existing `p/$LANGUAGE` registry check, the action detects repo content
and adds matching rulesets:

| File pattern | Ruleset | Rule count |
|---|---|---|
| `Dockerfile*` (excluding `.git/`) | `p/dockerfile` | 7 |
| `.github/workflows/*.yml` or `*.yaml` | `p/github-actions` | 3 |

Detection uses the same `find | head -1 | grep -q .` pattern from ci-quality's
`has_files` function. No registry check is needed for these — they are
known-valid rulesets.

Auto-detected rulesets are silently skipped when the file pattern doesn't match.
No `::notice` is emitted on skip (unlike the `p/$LANGUAGE` case, where skipping
is unexpected and worth flagging).

### Config construction order

1. `p/ci p/security-audit p/secrets` — base (always)
2. `p/$LANGUAGE` — if registry check passes
3. `p/dockerfile` — if Dockerfiles detected
4. `p/github-actions` — if workflow files detected
5. `extra-config` values — explicit opt-in, appended last

### What is NOT changing

- **No new inputs on `ci-security.yml`** — auto-detection is invisible to
  consuming repos. The `extra-config` input already exists on the action for
  edge cases; it does not need to be plumbed through the workflow.
- **`p/command-injection`** — excluded from auto-detection for now. The trigger
  condition is unclear (shell scripts are already partially covered by `p/ci`),
  and it can be revisited in a follow-up.
- **`p/owasp-top-ten`** — 544 rules, needs noise evaluation before adding
  fleet-wide. Out of scope.

### Documentation updates

- `docs/site/docs/actions/security-semgrep.md` — add `p/ci` to the base
  rulesets list in the Behavior section. Add an "Auto-detected rulesets"
  subsection documenting what triggers `p/dockerfile` and `p/github-actions`.
- `docs/site/docs/workflows/ci-security.md` — add a note in implementation
  notes that Semgrep auto-detects Dockerfile and GitHub Actions content.

### Self-referencing CI validation

This repo passes `language: shell` to ci-security. After this change:

- `p/ci` runs (base config) — new coverage
- `p/shell` is skipped (existing registry check, no change)
- `p/github-actions` is auto-detected (this repo has `.github/workflows/`)
- `p/dockerfile` is not triggered (no Dockerfiles in this repo)

This validates both the positive and negative auto-detection paths in the same
PR.

## Out of scope

- `p/command-injection` auto-detection (follow-up)
- `p/owasp-top-ten` evaluation (follow-up)
- `semgrep-extra-config` pass-through on `ci-security.yml` (not needed until a
  consuming repo has a use case the auto-detection doesn't cover)
