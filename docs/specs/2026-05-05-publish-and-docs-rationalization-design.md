# Rationalize publish and docs workflows as reusable workflows

**Issue:** [#318](https://github.com/wphillipmoore/standard-actions/issues/318)
**Date:** 2026-05-05
**Status:** Design

## Context

Issue standard-tooling#173 standardized the CI (pull request) workflows
across the fleet using a canonical check name registry and reusable
workflows in standard-actions. That work covered the five CI categories:
quality, test, audit, security, and release.

The remaining workflows — publish and documentation — need the same
rationalization: convert to reusable workflows in standard-actions, apply
the namespace convention, and reduce consuming repos to minimal
parameterized YAML.

## Design goals

1. Every consuming repo's `publish-release.yml` and `publish-docs.yml`
   are thin callers with zero (or near-zero) custom inputs.
2. All per-repo configuration lives in `standard-tooling.toml`, not in
   workflow YAML.
3. Check names follow the established `<category> / <job>` convention
   with space-slash-space separators.
4. No domain-specific knowledge (e.g., mq-rest-admin family) in
   standard-actions.

## Naming convention

### Check names

Both workflows are under the `publish` category:

| Reusable workflow file | Inner job name | Caller job key | Resulting check name |
|---|---|---|---|
| `publish-release.yml` | `release` | `publish` | `publish / release` |
| `publish-docs.yml` | `docs` | `publish` | `publish / docs` |

### File naming

Consuming repos name their thin callers identically to the reusable
workflow they call:

| Consuming repo file | Calls |
|---|---|
| `.github/workflows/publish-release.yml` | `standard-actions/.github/workflows/publish-release.yml` |
| `.github/workflows/publish-docs.yml` | `standard-actions/.github/workflows/publish-docs.yml` |

This replaces the current `publish.yml` and `docs.yml` filenames.

### Extended check name namespace

| Category | Check names | Type |
|---|---|---|
| `quality / ...` | `common`, `lint / <ver>`, `typecheck / <ver>` | CI gate (enforced) |
| `security / ...` | `standards`, `codeql`, `trivy`, `semgrep` | CI gate (enforced) |
| `test / ...` | `unit / <ver>`, `integration / <ver>` | CI gate (enforced) |
| `audit / ...` | `dependencies / <ver>` | CI gate (enforced) |
| `release / ...` | `version-bump` | CI gate (enforced) |
| `publish / ...` | `release`, `docs` | Post-merge (validated, not enforced) |

## Reusable workflow: `publish-docs.yml`

### Interface

Zero required inputs. The workflow reads `standard-tooling.toml` for
ecosystem detection and calls `st-version show --major-minor` for the
version.

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `pre-deploy-command` | string | no | `""` | Shell command to run before deploy |
| `mkdocs-config` | string | no | `"docs/site/mkdocs.yml"` | Path to mkdocs.yml |

No secrets required — uses `GITHUB_TOKEN` via `contents: write`.

### Behavior

1. Checkout with `fetch-depth: 0`
2. Read `standard-tooling.toml` to detect ecosystem
3. If `pre-deploy-command` is set, run it
4. Infer mike command: `uv run mike` for Python, `mike` for everything
   else (derived from `primary-language` in `standard-tooling.toml`)
5. Call `actions/docs-deploy` composite action with derived inputs
6. Version is obtained via `st-version show --major-minor`

### Trigger

Docs build on push to `main` and `develop`. On `main`, mike deploys the
versioned release with a `latest` alias. On `develop`, mike deploys a
`dev` version. This preserves the existing behavior from `docs.yml`.

Making the dev version discoverable via a well-known URL is tracked
separately (#328).

### Container

Runs in `ghcr.io/wphillipmoore/dev-base:latest` (same as today).

## Reusable workflow: `publish-release.yml` (refactored)

### Interface

Zero required inputs. The workflow reads `standard-tooling.toml` for
ecosystem, project name, and registry configuration. Version operations
use `st-version`.

All current inputs (`ecosystem`, `version-command`, `version-file`,
`version-regex`, `version-replacement`, `version-regex-multiline`,
`develop-version-command`, `post-bump-command`, `extra-files`,
`python-version`, `rust-toolchain`, `ruby-version`, `go-version-file`,
`java-version`, `java-distribution`, `release-title`, `release-notes`,
`release-artifacts`, `pr-body-extra`) are removed. Ecosystem-specific
build, registry-check, and registry-publish commands are derived from the
ecosystem identity.

Optional override inputs remain available for genuine edge cases but the
expectation is that callers never set them.

Secrets default to conventional names (`APP_ID`, `APP_PRIVATE_KEY`,
ecosystem-specific registry tokens). Callers use `secrets: inherit`.

### Behavior

1. Checkout with `fetch-depth: 0`
2. Read `standard-tooling.toml` for ecosystem and project identity
3. Set up language environment (conditional on ecosystem)
4. `st-version show` to extract current version
5. Check if tag already exists
6. Ecosystem-specific build (derived)
7. Build provenance attestation (if applicable)
8. SBOM generation (if applicable)
9. Registry check and publish (derived per ecosystem)
10. Tag and release — title: `<repo-name> v<version>`, body: link to
    GitHub Pages documentation site
11. Version bump PR — `st-version bump` handles version file update and
    lockfile maintenance (e.g., `uv lock` for Python)

### GitHub Release format

Auto-generated, no caller input:

- **Title:** `<repo-name> v<version>` (e.g., `mq-rest-admin-python v1.2.2`)
- **Body:** Link to the GitHub Pages documentation site

### What was removed

- **`uv export` for requirements.txt** — anachronism; all tooling uses
  uv directly. Dropped from all Python repos.
- **`uv lock --upgrade` in post-bump-command** — dependency upgrades are
  managed exclusively by the dependency-update workflow, not the version
  bump. The version-bump-pr action only runs the mechanical `uv lock`
  (without `--upgrade`) to fix the lockfile self-version entry.
- **All per-repo version parsing** — replaced by `st-version` which
  reads `standard-tooling.toml` and knows per-language conventions.

## Composite action changes

### `actions/publish/tag-and-release`

- Remove `release-title` and `release-notes` required inputs
- Derive title from `github.repository` + version
- Derive body as a static link to the GitHub Pages docs site using the
  standard `https://{owner}.github.io/{repo}/` convention (no API call
  needed — the naming convention is rigidly enforced)

### `actions/publish/version-bump-pr`

- Detect ecosystem from `standard-tooling.toml` (or accept an input)
- For Python: automatically run `uv lock` and stage `uv.lock` after
  version file edit
- Use `st-version bump` instead of caller-provided regex substitution
- `post-bump-command` and `extra-files` inputs remain available for
  edge cases but are empty for all standard configurations

### `actions/docs-deploy`

- Remove `checkout-common` and `checkout-common-ref` inputs and the
  corresponding mq-rest-admin-common checkout step. These are
  domain-specific (violates Design Goal #4). The mq-rest-admin family
  uses `pre-deploy-command` in the reusable workflow instead.
- No other interface changes needed — the reusable workflow handles
  `standard-tooling.toml` reading and mike command inference before
  calling this action

## `standard-tooling.toml` schema extension

New `[publish]` section:

```toml
[publish]
release = true    # whether the repo has a publish-release workflow
docs = true       # whether the repo has a publish-docs workflow (default expectation: true)
```

Every repo managed by standard-tooling is expected to have `docs = true`.
Setting it to `false` is permitted for special cases but is the exception.
`release` is optional and depends on whether the repo publishes versioned
artifacts.

Additional fields may be added for registry-specific configuration that
cannot be derived from the ecosystem identity. The goal is to keep all
per-repo configuration in this file rather than scattered across workflow
YAML.

## `st-github-config` extension

- Add `[publish]` section support to the config derivation engine
- Validate post-merge workflow naming compliance: check that
  `publish-release.yml` and `publish-docs.yml` use the canonical inner
  job names (`release` and `docs` respectively)
- Post-merge checks are validated but not enforced via rulesets (they
  are not required status checks)

## New CLI tool: `st-version`

A new standard-tooling CLI tool that encapsulates all version
management. Reads `standard-tooling.toml` for language and version file
location.

| Command | Description |
|---|---|
| `st-version show` | Print current version to stdout |
| `st-version show --major-minor` | Print major.minor (for docs versioning) |
| `st-version bump` | Increment patch version, update version file, maintain lockfile |

Per-language version file conventions (default discovery; overridable
via an optional `version_file` field in `standard-tooling.toml` if a
repo deviates from the convention):

| Language | Default version file | Pattern |
|---|---|---|
| python | `pyproject.toml` | `version = "x.y.z"` |
| ruby | auto-discover `lib/**/version.rb` | `VERSION = 'x.y.z'` |
| go | auto-discover `**/version.go` | `Version = "x.y.z"` |
| java | `pom.xml` | `<version>x.y.z</version>` |
| rust | `Cargo.toml` | `version = "x.y.z"` |
| generic | `VERSION` | plain `x.y.z` |

### Lockfile maintenance after bump

`st-version bump` runs the appropriate lockfile maintenance command
after editing the version file. The version bump does not upgrade
dependencies — it only fixes the lockfile to reflect the new
self-version entry.

| Language | Lockfile command | Notes |
|---|---|---|
| python | `uv lock` | Fixes `uv.lock` self-version; no `--upgrade` |
| rust | `cargo update --workspace` | Updates `Cargo.lock` self-version |
| ruby | `bundle install` | Regenerates `Gemfile.lock` |
| go | no lockfile maintenance | `go.sum` does not encode module version |
| java | no lockfile maintenance | Maven has no lockfile |
| generic | no lockfile maintenance | — |

## Consuming repo end state

### Publish release (repos that release artifacts)

```yaml
name: Publish release
on:
  push:
    branches: [main]
permissions:
  attestations: write
  contents: write
  id-token: write
  pull-requests: write
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

#### Secrets strategy

The examples above use `secrets: inherit` for simplicity — this passes
all repository secrets to the reusable workflow. This is appropriate
when the same party owns both the consuming repo and standard-actions.

For consumers who do not fully trust the reusable workflow owner, or
who prefer least-privilege, explicit secret forwarding is supported:

```yaml
    secrets:
      APP_ID: ${{ secrets.APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

The reusable workflow declares all accepted secrets with
`required: true/false`, so explicit forwarding works without changes
to the workflow itself.

### Publish docs (all repos)

```yaml
name: Publish docs
on:
  push:
    branches: [main]
permissions:
  contents: write
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-docs.yml@v1.5
```

### Special cases

- **standard-actions** — `publish-release.yml` stays bespoke due to the
  `freeze-internal-refs` step (self-referential action pinning). Job
  name is set to `"publish / release"` directly for naming consistency.
  `publish-docs.yml` becomes a thin caller of its own reusable workflow.

- **mq-rest-admin family** — uses `pre-deploy-command` to clone
  `mq-rest-admin-common` for shared documentation fragments. No
  domain-specific knowledge in standard-actions. A separate issue in
  mq-rest-admin-common tracks implementing a family-specific wrapper
  if the duplication across five repos warrants it.

- **the-infrastructure-mindset** — out of scope. Non-versioned blog
  site with no release workflow.

## Implementation ordering

1. **standard-tooling** — `st-version` CLI tool, `standard-tooling.toml`
   schema extension, `st-github-config` publish section support
2. **standard-actions** — reusable workflow creation/refactoring,
   composite action updates
3. **Fleet rollout** — update all consuming repos to thin callers,
   rename workflow files, add `[publish]` to `standard-tooling.toml`,
   remove requirements.txt generation and bespoke post-bump-commands

Breaking changes to existing interfaces are acceptable during this
rollout — there are no external consumers. A minor release of
standard-actions may be cut between phases if it eases deployment.

### Rollout mechanics per consuming repo

Each consuming repo's migration must be atomic within a single PR:
delete the old workflow file (`docs.yml`, `publish.yml`) and add the
new thin caller (`publish-docs.yml`, `publish-release.yml`) in the
same commit. If both old and new files exist simultaneously, both
trigger on push to main, causing duplicate deployments or race
conditions in the concurrency group.

## Follow-up issues

| Repository | Issue | Description |
|---|---|---|
| standard-tooling | `st-version` CLI tool | New tool for version show/bump across all languages |
| standard-tooling | Dev docs preview | Evaluate publishing development docs from develop merges to a separate path for QA before release |
| standard-tooling | v2.0 auto-generated API docs | Revisit mkdocstrings (Python), Javadoc (Java), and equivalents for Ruby/Go/Rust |
| standard-tooling | Version command abstraction | Rationalize all version parsing into `st-version` |
| mq-rest-admin-common | Bespoke docs workflow | Implement family-specific docs workflow for common fragments checkout |
