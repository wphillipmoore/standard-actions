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
- All `uses:` path updates in workflow and action files
- Deletion of dead code (`actions/python/setup/`)
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
| `actions/publish/freeze-internal-refs/` | `actions/local/freeze-internal-refs/` |
| `actions/python/setup/` | *(delete — dead code, unreferenced)* |

### Reference updates

Every `uses:` path in workflow and action files updates to match the new
directory structure.

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

This reference appears in eight workflows: `ci-quality.yml`, `ci-test.yml`,
`ci-audit.yml`, `ci-version-bump.yml`, `ci-security.yml`, `cd.yml`,
`cd-docs.yml`, `ops-github-config.yml`.

#### Remote ref updates

| Workflow | Old `uses:` | New `uses:` |
|----------|------------|-------------|
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/setup/standard-tooling@develop` | `wphillipmoore/standard-actions/actions/shared/setup/standard-tooling@develop` |
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| `cd-release.yml` | `wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |
| `cd.yml` | `wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| `cd.yml` | `wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |

#### Action-to-action reference updates

Some composite actions reference other actions. These paths also need
updating:

| Action file | Old `uses:` | New `uses:` |
|-------------|------------|-------------|
| `standards-compliance/action.yml` | `./actions/setup/standard-tooling` | `./actions/shared/setup/standard-tooling` |
| `registry-publish/action.yml` | `wphillipmoore/standard-actions/actions/security/trivy@develop` | `wphillipmoore/standard-actions/actions/shared/security/trivy@develop` |

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

### freeze-internal-refs compatibility

The `freeze-internal-refs` action rewrites action paths in workflow and
action YAML files. Its sed pattern (`\./actions/([^[:space:]]+)`) captures
everything after `./actions/` up to whitespace, regardless of path depth.
Paths like `./actions/ci/security/codeql` (three levels) work identically
to the current two-level paths. No changes to the action are needed.
Confirm with a test during implementation.

## Migration strategy

### Single atomic PR

All changes land in one PR:

1. `git mv` every action to its new path.
2. Delete dead code: `rm -rf actions/python/setup/`.
3. Update all `uses:` references in workflow and action files.
4. Rename the `registry-publish-command` input to `publish-command` in
   `cd-release.yml`.
5. Update `CLAUDE.md`.
6. Update MkDocs site docs.
7. Run `st-validate` to confirm everything passes.

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
pipeline phase, and add the navigation convention note explaining the
phase/domain/action hierarchy and the `shared/` and `local/` directories.

### MkDocs site

The documentation impact is significant — action paths appear throughout
the site. Three categories of changes:

**1. Action doc page renames** (`docs/site/docs/actions/`):

| Old filename | New filename |
|-------------|-------------|
| `standards-compliance.md` | `ci-security-standards-compliance.md` |
| `security-codeql.md` | `ci-security-codeql.md` |
| `security-semgrep.md` | `ci-security-semgrep.md` |
| `security-trivy.md` | `shared-security-trivy.md` |
| `release-gates-version-divergence.md` | `ci-version-bump-version-divergence.md` |
| `publish-tag-and-release.md` | `cd-release-tag-and-release.md` |
| `publish-version-bump-pr.md` | `cd-release-version-bump-pr.md` |
| `docs-deploy.md` | `cd-docs-deploy.md` |
| `python-setup.md` | *(delete — action removed)* |

**2. Remote action path references** in code examples and usage snippets
across multiple doc pages. Every occurrence of
`wphillipmoore/standard-actions/actions/<old-path>@v1.5` must update to
the new path (e.g., `actions/security/codeql` →
`actions/ci/security/codeql`).

Affected files include: `getting-started.md`, `index.md`,
`configuration.md`, `development/contributing.md`,
`ci-gates/security-scanning.md`, `ci-gates/index.md`, and every
individual action doc page.

**3. mkdocs.yml nav entries** must update to reference the new doc page
filenames.

**4. contributing.md** describes the convention for adding new actions
(`actions/<category>/<action-name>/action.yml`). This must be updated to
describe the new `actions/{phase}/{domain}/{action}/` convention with
guidance on when to use `shared/` vs a phase-specific directory.
