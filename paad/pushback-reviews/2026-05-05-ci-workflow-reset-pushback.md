# Pushback Review: CI reusable workflow reset — unified validation architecture

**Date:** 2026-05-05
**Spec:** `docs/specs/2026-05-05-ci-workflow-reset-design.md`
**Commit:** f59fe734edcba326ffe74cb2780e34fde994edb8

## Source Control Conflicts

PR #336 (merged 2026-05-01) removed `|| true` suppression from yamllint,
markdownlint, hadolint, and actionlint in ci-quality.yml. The spec's
context section describes ci-quality.yml as "suppressing 4 of 5 failures
with `|| true`" — that's now stale. The current state already enforces
all 5 common checks. This doesn't invalidate the design (the workflows
are still bespoke inline scripts, not `st-validate`), but the urgency
framing is slightly outdated. The spec context section was updated to
reflect this.

## Issues Reviewed

### [1] Feasibility — `if:` conditional to skip lint/typecheck for unsupported languages

- **Category:** Feasibility
- **Severity:** Serious
- **Issue:** The spec says lint and typecheck jobs use `if:` to skip when
  the language has no registry entry. But there's no mechanism for the
  workflow to query the registry at YAML evaluation time — `if:`
  conditions evaluate before any step runs.
- **Resolution:** Always run the jobs. `st-validate` exits 0 with a
  message like "no lint commands for language 'shell'" when the registry
  has nothing. No conditional `if:`, no probe step. Phantom checks are
  harmless; `st-github-config` controls what's required. The no-op jobs
  also serve as natural placeholders that get filled in as tooling
  matures for each language.

### [2] Ambiguity — Integration test interface is unresolved

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The spec includes an `integration` job in ci-test.yml with
  the note "the exact interface for specifying integration test commands
  is deferred." Investigation of all five mq-rest-admin repos showed
  integration tests follow a uniform pattern (same setup action, same env
  vars, same matrix structure) but the service provisioning and port
  allocation are product-specific, not generic.
- **Resolution:** Remove the `integration` job and `integration-tests`
  input from ci-test.yml. The reusable workflow handles `unit` only.
  Integration test support means `st-github-config` generates the
  required check name (`test / integration / <ver>`) when a repo
  declares integration tests. Implementation is repo-local, constrained
  only by the check naming convention.

### [3] Omission — No rollback plan if `st-validate` has a bug

- **Category:** Omission
- **Severity:** Moderate
- **Issue:** The spec replaces 10+ existing commands and all
  `scripts/dev/` scripts with a single `st-validate` command. A bug
  would break every repo's CI and local validation simultaneously.
- **Resolution:** No explicit rollback plan needed. Scale of one — the
  developer is the only consumer. The fleet is on hold during this
  transition. Version pinning provides an implicit rollback path. Fix
  forward; the self-referencing CI in standard-actions validates
  workflows before release.

### [4] Ambiguity — Common checks file-discovery scope differs from current CI

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The spec's common checks describe narrower scopes
  (markdownlint for `docs/site/` + `README.md` only) than ci-quality.yml
  uses today (`**/*.md`). Also, ci-quality.yml currently runs hadolint
  and actionlint, which aren't listed in the spec's common checks.
- **Resolution:** The spec's narrow markdownlint scope is correct — it
  matches the existing validated implementation in `st-validate-local-common`
  (standard-tooling). The broader scope in ci-quality.yml is the bespoke
  inline code being replaced. Add hadolint and actionlint to the common
  checks list: hadolint runs if `Dockerfile*` files exist, actionlint
  runs if `.github/workflows/` directory exists.

### [5] Ambiguity — ci-release.yml version-bump job references the existing version-divergence action but doesn't describe how inputs are provided

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The `version-divergence` action requires `head-version-command`
  and `main-version-command` inputs — repo-specific shell commands. The
  spec doesn't describe how these are provided.
- **Resolution:** Use `st-version show` (from the publish-and-docs
  rationalization spec, issue #318) as the version commands. This
  replaces caller-provided per-language version commands. The
  version-divergence action's interface stays unchanged; the workflow
  passes `st-version show` as the head-version-command and uses a
  temporary worktree for the main-version-command.

### [6] Omission — No coordination with the publish-and-docs rationalization spec (#318)

- **Category:** Omission
- **Severity:** Serious
- **Issue:** Both the CI workflow reset spec and the publish-and-docs
  rationalization spec (#318) require standard-tooling work in Phase 1.
  The CI reset needs `st-validate`, and the publish/docs work needs
  `st-version`. Both need a standard-tooling release before their
  standard-actions phases can proceed. The specs are written as
  independent timelines with no cross-references.
- **Resolution:** Coordinate the two specs into a single standard-tooling
  release. Phase 1 becomes a combined effort: `st-validate` + registry
  updates (from this spec), `st-version` + `[publish]` config (from
  #318). This avoids two sequential standard-tooling releases and
  ensures both standard-actions phases can proceed without blocking
  each other.

### [7] Omission — version-divergence action modification not described

- **Category:** Omission
- **Severity:** Minor
- **Issue:** The spec says ci-release.yml "uses the existing
  `actions/release-gates/version-divergence` composite action" but the
  action requires command inputs that the spec doesn't describe.
- **Resolution:** Keep the version-divergence action's generic interface.
  The ci-release.yml workflow passes `st-version show` as inputs. The
  spec documents this explicitly.

## Summary

- **Issues found:** 7
- **Issues resolved:** 7
- **Unresolved:** 0
- **Spec status:** Ready for implementation after applying resolutions
