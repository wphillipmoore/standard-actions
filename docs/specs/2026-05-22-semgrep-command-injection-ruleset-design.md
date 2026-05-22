# Semgrep Command-Injection Ruleset Expansion

**Issue:** #321
**Date:** 2026-05-22
**Status:** Approved

## Goal

Add `p/command-injection` to the Semgrep action's base config so every repo in
the fleet gets unsafe-shell-construction scanning by default, with no
configuration required from consuming repos.

## Background

Issue #303 identified several high-value Semgrep rulesets not being used. PR
#320 addressed the first batch — adding `p/ci` to the base config and
implementing auto-detection for `p/dockerfile` and `p/github-actions`. Issue
#321 covers the remaining rulesets: `p/command-injection` (30 rules) and
`p/owasp-top-ten` (544 rules).

### Fleet analysis

A survey of all 13 consuming repos across the Diogenes, MQ REST Admin, and
Vergil projects shows:

- **Shell scripts are pervasive** — present in 12 of 13 repos, from
  infrastructure-only repos to language-specific application repos.
- **No web applications exist** in the fleet today — `p/owasp-top-ten` has no
  current applicability.
- **No repo uses `extra-config`** today — all rulesets are either base config or
  auto-detected.

### Decision on `p/owasp-top-ten`

Deferred. The 544-rule web-security ruleset targets application patterns (SQL
injection, XSS, CSRF, etc.) that do not exist in the current fleet. Adding it
would impose scan overhead with no signal. A separate backlog issue will track
this for when web-facing services enter the fleet.

## Design

### Action change

One-line edit to `actions/ci/security/semgrep/action.yml`. The base config
string changes from:

```bash
config="p/ci p/security-audit p/secrets"
```

to:

```bash
config="p/ci p/command-injection p/security-audit p/secrets"
```

### Config construction order

1. `p/ci p/command-injection p/security-audit p/secrets` — base (always)
2. `p/$LANGUAGE` — if registry check passes
3. `p/dockerfile` — if Dockerfiles detected
4. `p/github-actions` — if workflow files detected
5. `extra-config` values — explicit opt-in, appended last

### What is NOT changing

- **No new inputs** on the action or on `ci-security.yml`.
- **No new auto-detection logic** — `p/command-injection` is unconditional.
  Auto-detection was considered and rejected because shell scripts exist in
  nearly every repo, making conditional logic functionally equivalent to
  always-on but more complex.
- **No opt-out mechanism** — consistent with the existing base rulesets (`p/ci`,
  `p/security-audit`, `p/secrets`). If a repo produces unacceptable
  false-positive noise, an opt-out input can be added in a follow-up.
- **No changes to consuming repos** — the new ruleset applies automatically on
  the next CI run.

### Documentation updates

**`docs/site/docs/actions/ci-security-semgrep.md`:**

- Add `p/command-injection` to the rulesets list in the Behavior section,
  described as "Unsafe shell construction and command injection patterns."
- Add a "Future rulesets" section at the end of the file noting that additional
  rulesets (such as `p/owasp-top-ten`) can be enabled per-repo via the
  `extra-config` input, and are not included in the base config because they
  target specific application types not shared across the fleet.

### Backlog issue

Create a GitHub issue to track `p/owasp-top-ten` as a future enhancement:

- **Title:** Add `p/owasp-top-ten` Semgrep ruleset for web application repos
- **Content:** 544-rule OWASP Top 10 web security ruleset. Not relevant to the
  current fleet (no web applications). Evaluate signal-to-noise ratio when a
  web-facing service enters the fleet and decide whether to add to base config
  or keep as opt-in via `extra-config`.
- **Context references:** #303, #320, #321
- **Label:** enhancement

### Self-referencing CI validation

This repo passes `language: shell` to ci-security. After this change, the
Semgrep scan for vergil-actions runs:

| Ruleset | Source | Expected |
|---------|--------|----------|
| `p/ci` | base | runs |
| `p/command-injection` | base (new) | runs |
| `p/security-audit` | base | runs |
| `p/secrets` | base | runs |
| `p/shell` | registry check | skipped (404) |
| `p/github-actions` | auto-detected | runs |
| `p/dockerfile` | auto-detected | not triggered |

The new ruleset is exercised by the repo's own CI pipeline. Any findings on the
repo's shell scripts surface as code scanning alerts.

## Out of scope

- `p/owasp-top-ten` evaluation (tracked in a separate backlog issue)
- Per-repo opt-out mechanism for base rulesets (not needed until there is
  evidence of false-positive noise)
- Plumbing `extra-config` through `ci-security.yml` (not needed until a
  consuming repo has a use case the base config and auto-detection don't cover)
