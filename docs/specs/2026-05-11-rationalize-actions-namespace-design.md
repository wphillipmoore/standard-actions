# Rationalize actions/ namespace to align with workflow hierarchy

**Issue:** [#440](https://github.com/wphillipmoore/standard-actions/issues/440)
**Date:** 2026-05-11
**Status:** Approved

## Problem

The `actions/` directory grew organically through incremental changes and ad
hoc feature additions. The result is an inconsistent namespace where
directory structure does not predictably map to the workflow files that
consume each action. A human reading `ci-security.yml` cannot intuitively
find its composite actions without guessing.

Specific inconsistencies:

- Top-level singletons (`docs-deploy`, `standards-compliance`) sit at the
  root with no namespace while siblings live in grouped directories.
- `release-gates/version-divergence` maps to `ci-version-bump.yml` — the
  namespace does not echo the workflow name.
- `standards-compliance` is called from `ci-security.yml` but does not live
  under `security/`.
- Cross-cutting actions (`security/trivy`, `setup/standard-tooling`) lack a
  clear home that acknowledges their shared nature.

## Scope

**In scope:**

- Directory restructure of `actions/` to mirror the workflow namespace
- All `uses:` path updates in workflow files
- Input name harmonization (one mismatch)
- CLAUDE.md and MkDocs documentation updates

**Out of scope:**

- `language` input semantics (dual role as container selector and build
  pipeline selector) — potential follow-on issue
- Client repo workflow structure changes (except the one `publish-command`
  input rename)

## Consumption model

Understanding the consumption model is critical to scoping this change:

1. **Client repos** have thin `ci.yml` / `cd.yml` / `ops.yml` files that
   call standard-actions' reusable workflows via `workflow_call`.
2. **Reusable workflows** (`ci-quality.yml`, `cd-release.yml`, etc.) are
   the second level — what clients bind to.
3. **Composite actions** (`actions/*`) are only referenced by those reusable
   workflows, never directly by consumers.

The `actions/` namespace is internal to this repo. Directory renames do not
require consumer migration — we update the `uses:` paths in the reusable
workflows in the same PR.

## Design

### Naming convention

The `actions/` directory mirrors the workflow namespace using a three-level
hierarchy:

```
actions/{phase}/{domain}/{action}/action.yml
```

- **Phase** (`ci`, `cd`): when in the pipeline the action runs.
- **Domain** (`security`, `release`, `version-bump`, `docs`): what
  functional area the action addresses, matching the domain segment of the
  workflow filename.
- **Action**: the leaf directory containing `action.yml`.

Two additional top-level directories exist outside the phase/domain
hierarchy:

- **`shared/`**: cross-phase actions used by workflows in multiple phases.
- **`local/`**: bespoke actions specific to this repo, not reexported as
  part of the library.

**Navigation rule:** To find an action, take the workflow filename (e.g.,
`ci-security.yml`), split on the first `-` to get phase and domain
(`ci` / `security`), and look in `actions/{phase}/{domain}/`. Cross-phase
actions live in `actions/shared/`. Repo-local actions live in
`actions/local/`.

### Directory structure

```
actions/
  ci/
    security/
      standards-compliance/action.yml
      codeql/action.yml
      semgrep/action.yml
    version-bump/
      version-divergence/action.yml
  cd/
    release/
      validate-inputs/action.yml
      registry-publish/action.yml
      tag-and-release/action.yml
      version-bump-pr/action.yml
    docs/
      deploy/action.yml
  shared/
    security/
      trivy/action.yml
    setup/
      standard-tooling/action.yml
      python/action.yml
  local/
    freeze-internal-refs/action.yml
```

### Move table

| Old path | New path |
|----------|----------|
| `actions/standards-compliance/` | `actions/ci/security/standards-compliance/` |
| `actions/security/codeql/` | `actions/ci/security/codeql/` |
| `actions/security/semgrep/` | `actions/ci/security/semgrep/` |
| `actions/security/trivy/` | `actions/shared/security/trivy/` |
| `actions/release-gates/version-divergence/` | `actions/ci/version-bump/version-divergence/` |
| `actions/publish/validate-inputs/` | `actions/cd/release/validate-inputs/` |
| `actions/publish/registry-publish/` | `actions/cd/release/registry-publish/` |
| `actions/publish/tag-and-release/` | `actions/cd/release/tag-and-release/` |
| `actions/publish/version-bump-pr/` | `actions/cd/release/version-bump-pr/` |
| `actions/docs-deploy/` | `actions/cd/docs/deploy/` |
| `actions/setup/standard-tooling/` | `actions/shared/setup/standard-tooling/` |
| `actions/python/setup/` | `actions/shared/setup/python/` |
| `actions/publish/freeze-internal-refs/` | `actions/local/freeze-internal-refs/` |

### Workflow reference updates

Every `uses:` path in the workflow files updates to match the new directory
structure.

#### Local path updates

| Workflow | Old `uses:` | New `uses:` |
|----------|------------|-------------|
| `ci-security.yml` | `./actions/standards-compliance` | `./actions/ci/security/standards-compliance` |
| `ci-security.yml` | `./actions/security/codeql` | `./actions/ci/security/codeql` |
| `ci-security.yml` | `./actions/security/trivy` | `./actions/shared/security/trivy` |
| `ci-security.yml` | `./actions/security/semgrep` | `./actions/ci/security/semgrep` |
| `ci-version-bump.yml` | `./actions/release-gates/version-divergence` | `./actions/ci/version-bump/version-divergence` |
| `cd-release.yml` | `./actions/publish/validate-inputs` | `./actions/cd/release/validate-inputs` |
| `cd-release.yml` | `./actions/publish/registry-publish` | `./actions/cd/release/registry-publish` |
| `cd-docs.yml` | `./actions/docs-deploy` | `./actions/cd/docs/deploy` |
| `cd.yml` | `./actions/publish/freeze-internal-refs` | `./actions/local/freeze-internal-refs` |

#### `./actions/setup/standard-tooling` → `./actions/shared/setup/standard-tooling`

This reference appears in seven workflows: `ci-quality.yml`, `ci-test.yml`,
`ci-audit.yml`, `ci-version-bump.yml`, `cd.yml`, `cd-docs.yml`,
`ops-github-config.yml`.

#### Remote ref updates

| Workflow | Old `uses:` | New `uses:` |
|----------|------------|-------------|
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/setup/standard-tooling@develop` | `wphillipmoore/standard-actions/actions/shared/setup/standard-tooling@develop` |
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |
| `cd.yml` | `wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| `cd.yml` | `wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |

### Input name harmonization

One mismatch exists between workflow and action input names:

| Layer | Current name | New name |
|-------|-------------|----------|
| `cd-release.yml` workflow input | `registry-publish-command` | `publish-command` |
| `cd/release/registry-publish/action.yml` input | `publish-command` | `publish-command` (unchanged) |

The action already uses the correct name. The workflow input added a
`registry-` prefix that creates a name translation. Fix: rename the workflow
input to `publish-command`.

**Consumer impact:** Any consumer repo calling `cd-release.yml` that passes
`registry-publish-command` must update to `publish-command`. This is a
one-line change per consumer.

### freeze-internal-refs update

The `freeze-internal-refs` action rewrites action paths in workflow and
action YAML files. Its path-matching logic must be verified to ensure it
handles the new deeper directory structure correctly. Specifically, the
regex or glob patterns that find `./actions/` references and rewrite them
to absolute tagged refs need to work with paths like
`./actions/ci/security/codeql` (three levels deep) and
`./actions/shared/setup/standard-tooling` (three levels deep), not just
the current two-level paths.

## Migration strategy

### Single atomic PR

All changes land in one PR:

1. `git mv` every action to its new path.
2. Update all `uses:` references in workflow files.
3. Rename the `registry-publish-command` input to `publish-command` in
   `cd-release.yml`.
4. Update `CLAUDE.md`.
5. Update MkDocs site docs.
6. Run `st-validate` to confirm everything passes.

No deprecation window, no aliases, no shims. The old paths stop existing.
Since this repo's CI uses local paths (`./actions/...`), the PR validates
that all references resolve correctly.

### Consumer updates

The `publish-command` input rename affects consumer repos that call
`cd-release.yml` with `registry-publish-command`. Update consumer
`cd.yml` files at the same time as the standard-actions release. No
backward-compatibility fallback — that would add exactly the kind of
name translation this work eliminates.

### Versioning

This reorganization with one breaking input rename warrants a minor version
bump (e.g., 1.6.0). The rolling minor tag (`@v1.6`) gives consumers a
clear migration point.

## Documentation updates

### CLAUDE.md

Replace the current action listing with the new structure organized by
pipeline phase, and add the navigation convention note.

### MkDocs site

Update action path references in `docs/site/docs/getting-started.md` and
`docs/site/docs/index.md` to use the new paths.
