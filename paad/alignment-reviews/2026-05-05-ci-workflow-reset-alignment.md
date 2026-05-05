# Alignment Review: CI workflow reset (#337)

**Date:** 2026-05-05
**Commit:** 353d9b9

## Documents Reviewed

- **Intent:** GitHub issue #337 (CI reusable workflows are stubs)
- **Design:** `docs/specs/2026-05-05-ci-workflow-reset-design.md`
- **Action:** `docs/plans/2026-05-05-ci-workflow-reset.md`
- **Supplementary:** `paad/pushback-reviews/2026-05-05-ci-workflow-reset-pushback.md`

## Source Control Conflicts

None — no conflicts with recent changes. PR #336 (removing `|| true`
suppressions) is already reflected in the spec and plan. PR #334
(publish-and-docs rationalization) is correctly cross-referenced as a
coordination dependency.

## Issues Reviewed

### [1] `integration-tests` input removal is a breaking change

- **Category:** Missing coverage
- **Severity:** Minor
- **Documents:** Plan Task 9 vs current ci-test.yml on `develop`
- **Issue:** Plan Task 9 removes the `integration-tests` input and
  `integration` job from ci-test.yml. Any consumer repo passing
  `integration-tests: true` would get a workflow call error after
  upgrading to v1.6.
- **Resolution:** Non-issue. Scale of one, fleet frozen, consumer repos
  will be brought up to speed during the Phase 3 re-sweep. No changes
  needed.

### [2] `main-version-command` runs in the PR branch working tree

- **Category:** Design gap
- **Severity:** Important
- **Documents:** Plan Task 11, Design spec Part 3 (ci-release.yml),
  version-divergence action
- **Issue:** The version-divergence action fetches `origin/main` but
  never checks it out. Both `head-version-command` and
  `main-version-command` execute in the PR branch's working tree,
  so passing `st-version show` for both would return the same version.
  The design spec mentioned a temporary worktree but neither the plan
  nor the action implemented it.
- **Resolution:** Add `--ref` argument to `st-version show`. The
  `--ref` argument reads the version file via `git show <ref>:<path>`
  instead of the filesystem, avoiding worktree or checkout
  manipulation. ci-release.yml passes `st-version show` for head and
  `st-version show --ref origin/main` for main. The `--ref`
  requirement flows into the #318 plan's `st-version` tasks (Task 6
  in this plan, Tasks 2-3 in the #318 plan). Applied to both spec
  and plan.

### [3] `dev-shell` container image does not exist

- **Category:** Design gap
- **Severity:** Important
- **Documents:** Plan Tasks 8-10 YAML, Design spec Part 3 (container
  image selection)
- **Issue:** Language-versioned workflow jobs use
  `dev-<language>:<version>` as the container. For `language: shell`,
  this resolves to `dev-shell:latest`, which does not exist. The design
  spec said shell/none should use `dev-base` but the YAML template
  applied `dev-<language>` unconditionally.
- **Resolution:** Use an inline expression to map `shell` and `none`
  to `dev-base`:
  `dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}`.
  Applied to ci-quality.yml (Task 8), ci-test.yml (Task 9), and
  ci-audit.yml (Task 10) in both spec and plan.

### [4] Task 13 uses old `st-validate-local` command name

- **Category:** Minor inconsistency
- **Severity:** Minor
- **Documents:** Plan Task 13 Step 1
- **Issue:** Task 13 Step 1 said `st-docker-run -- st-validate-local`
  but by this point in the plan, `st-validate` is the canonical
  command.
- **Resolution:** Updated to `st-docker-run -- st-validate`.

## Unresolved Issues

None.

## Alignment Summary

- **Requirements:** 7 total, 7 covered, 0 gaps
- **Tasks:** 16 total, 16 in scope, 0 orphaned
- **Design items:** All aligned after applying resolutions
- **Status:** Aligned — ready for implementation
