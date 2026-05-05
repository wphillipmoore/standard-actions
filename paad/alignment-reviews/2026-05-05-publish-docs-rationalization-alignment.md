# Alignment Review: Publish and Docs Rationalization

**Date:** 2026-05-05
**Commit:** 113a99a91b5e728bbb5a53a8493148f8029f8ceb

## Documents Reviewed

- **Intent:** GitHub issue #318 ("Rationalize publish and docs workflows as reusable workflows")
- **Design:** `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`
- **Action:** `docs/plans/2026-05-05-publish-and-docs-rationalization.md`

## Source Control Conflicts

None — no conflicts with recent changes. The codebase is at v1.5.2,
the reusable CI workflows (#173) have landed, and the files the plan
targets match what the documents assume.

## Issues Reviewed

### [1] File naming collision: reusable workflows and standard-actions callers

- **Category:** Design gap (plan contradicts itself)
- **Severity:** Critical
- **Documents:** Plan Tasks 7/8 and Tasks 12/13; Design spec "Special cases" section

- **Issue:** The plan creates reusable workflows at
  `.github/workflows/publish-docs.yml` and
  `.github/workflows/publish-release.yml` (with `workflow_call`
  triggers). It then overwrites both files with standard-actions'
  own callers in Tasks 8 and 13. Task 8's thin caller also
  self-references circularly (`uses: ./.github/workflows/publish-docs.yml`
  pointing at itself). The design spec has the same blind spot — it
  says standard-actions' `publish-docs.yml` becomes a thin caller of
  its own reusable workflow, without noting the filename collision.

- **Resolution:** Two different fixes depending on the workflow:

  **publish-docs.yml:** Use dual triggers (`push` + `workflow_call`)
  in a single file. Standard-actions' `publish-docs.yml` serves as
  both the reusable workflow for consuming repos and the
  directly-triggered workflow for standard-actions itself. Delete the
  old `docs.yml`. Filename stays consistent everywhere.

  **publish-release.yml:** Dual triggers cannot work here because
  standard-actions' release workflow is structurally different from
  the reusable one (app token at checkout, freeze-internal-refs step,
  no build/publish). Standard-actions keeps `publish.yml` as its
  bespoke release workflow; `publish-release.yml` is the reusable
  workflow for consuming repos.

  Plan updated: Tasks 7/8 merged — `publish-docs.yml` created with
  dual triggers, `docs.yml` deleted in the same commit. Task 13
  updated with rationale for why `publish.yml` stays bespoke.

### [2] `st-version bump` does not include lockfile maintenance

- **Category:** Design gap (plan contradicts spec)
- **Severity:** Important
- **Documents:** Design spec "New CLI tool: st-version" table vs Plan Task 3

- **Issue:** The design spec defines `st-version bump` as performing
  three operations: increment patch version, update version file,
  and maintain lockfile. The plan's Task 3 implementation explicitly
  contradicts this — the `bump()` function's docstring says "Does not
  run lockfile maintenance." Instead, lockfile maintenance is
  implemented as a separate shell step in the `version-bump-pr`
  composite action (Task 11 Step 4). This means CLI invocations of
  `st-version bump` silently skip lockfile maintenance.

- **Resolution:** Move lockfile maintenance into the Python library
  (`bump()` calls `_run_lockfile_maintenance()` after writing the
  version file). General principle: when logic can live in either
  action YAML/shell or Python, prefer Python for testability and
  reuse. Remove the separate shell step from Task 11.

  Plan updated: Task 3 Step 3 updated with lockfile maintenance in
  `bump()`; new tests added; Task 11 Step 4 removed.

### [3] Registry check and credential guard logic missing

- **Category:** Missing coverage
- **Severity:** Important
- **Documents:** Design spec "Behavior" section vs Plan Task 12

- **Issue:** The design spec says "Ecosystem-specific build,
  registry-check, and registry-publish commands are derived from the
  ecosystem identity." The plan's Task 12 Step 5 only derives `build`
  and `publish` commands — `registry-check` is never derived. The
  credential guard pattern (graceful skip when secrets are not
  configured) is also dropped without replacement. This would cause
  double-publish attempts and hard failures on missing secrets.

- **Resolution:** Add `registry-check` derivation to Task 12 Step 5
  alongside `build` and `publish`. Keep the credential guard as
  derived shell logic per ecosystem. Kept in shell rather than Python
  because the logic depends on GitHub Actions secrets context
  expressions which only exist at workflow runtime.

  Plan updated: Task 12 Step 5 updated with `registry-check` and
  `credential-guard` derivation.

## Unresolved Issues

None — all issues addressed.

## Alignment Summary

- **Requirements:** 15 total, 12 fully covered, 3 gaps (all resolved)
- **Tasks:** 17 total, 17 in scope, 0 orphaned
- **Design items:** All aligned after fixes
- **Status:** Aligned after plan updates applied
