# Pushback Review: Rationalize publish and docs workflows

**Date:** 2026-05-05
**Spec:** docs/specs/2026-05-05-publish-and-docs-rationalization-design.md
**Commit:** ef690b9112ae2f859e09f2e03f90336dbf5c71ff

## Source Control Conflicts

None — no conflicts with recent changes. The spec builds on the CI
workflow rationalization from standard-tooling#173, and recent commits
(reusable CI workflows, v1.5 docs updates, st-config.toml removal) are
consistent with the spec's direction.

## Issues Reviewed

### [1] Develop branch docs deployment regression
- **Category:** Omissions
- **Severity:** Serious
- **Issue:** The current `docs.yml` triggers on both `develop` and `main`,
  deploying a `dev` version on develop merges. The spec scoped this out,
  which would silently remove working functionality from all repos.
- **Resolution:** `publish-docs.yml` triggers on both `develop` and `main`,
  preserving existing behavior. Dev docs well-known URL tracked separately
  as #328.

### [2] `docs-deploy` domain-specific inputs contradict Design Goal #4
- **Category:** Contradictions
- **Severity:** Moderate
- **Issue:** The spec said "No interface changes needed" for `docs-deploy`,
  but the action has `checkout-common` and `checkout-common-ref` inputs
  specific to the mq-rest-admin family, violating Design Goal #4 ("No
  domain-specific knowledge in standard-actions").
- **Resolution:** Remove `checkout-common` and `checkout-common-ref` from
  `docs-deploy`. The mq-rest-admin family uses `pre-deploy-command` instead.

### [3] GitHub Pages URL derivation for release body is fragile
- **Category:** Feasibility
- **Severity:** Serious
- **Issue:** The spec proposed deriving the release body by querying the
  GitHub Pages URL via API. Not all repos have Pages configured at first
  release, and the action would need to know mike's URL scheme to construct
  versioned links.
- **Resolution:** Use a static link derived from repository metadata using
  the standard `https://{owner}.github.io/{repo}/` convention. No API call
  needed — the naming convention is rigidly enforced.

### [4] `st-version bump` lockfile maintenance underspecified
- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The spec defined Python's lockfile behavior (`uv lock`) but
  left other ecosystems undefined. Since `post-bump-command` is being
  removed as the default mechanism, `st-version bump` needs to know what
  to run per ecosystem.
- **Resolution:** Added per-ecosystem lockfile maintenance table to the
  spec (python: `uv lock`, rust: `cargo update --workspace`, ruby:
  `bundle install`, go/java/generic: no lockfile maintenance).

### [5] TOML field naming inconsistency
- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The spec referenced `primary_language` (underscore) but the
  existing `standard-tooling.toml` uses `primary-language` (hyphen),
  consistent with all other TOML keys in the project.
- **Resolution:** Fixed spec to use `primary-language` (hyphen).

### [6] Dual workflow files during rollout could double-trigger
- **Category:** Omissions
- **Severity:** Moderate
- **Issue:** The spec didn't specify rollout mechanics. If a consuming repo
  adds the new thin caller before deleting the old workflow file, both
  trigger on push to main, causing duplicate deployments.
- **Resolution:** Added rollout note: old file deletion and new file
  addition must happen in the same PR per repo.

### [7] `secrets: inherit` passes all repository secrets
- **Category:** Security concerns
- **Severity:** Minor
- **Issue:** The consuming repo examples use `secrets: inherit`, which
  passes every repository secret to the reusable workflow — broader scope
  than necessary.
- **Resolution:** Keep `secrets: inherit` as the default for repos owned
  by the same party. Document both approaches (inherit vs. explicit
  forwarding) with trade-offs so external consumers can make an informed
  choice.

## Summary

- **Issues found:** 7
- **Issues resolved:** 7
- **Unresolved:** 0
- **Spec status:** Ready for implementation
