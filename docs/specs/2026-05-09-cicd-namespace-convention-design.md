# CI/CD namespace convention for shared vs local workflows

**Issue:** [#383](https://github.com/wphillipmoore/standard-actions/issues/383)
**Date:** 2026-05-09
**Status:** Design
**Milestone:** v1.5

## Context

All workflow files live in the flat `.github/workflows/` directory
(GitHub does not support subdirectories). The current naming makes it
hard to tell at a glance which files are reusable workflows consumed by
the fleet and which are local to the repository.

The original issue proposed a `shared-` prefix. During design, a cleaner
convention emerged: align workflow filenames to the CI/CD lifecycle. CI
workflows are pre-merge gates; CD workflows are post-merge delivery.
The naming convention itself communicates the role — no prefix needed.

## Naming convention

### Pattern

| Pattern | Role | Trigger |
|---|---|---|
| `ci.yml` | Local umbrella | `pull_request` |
| `ci-*.yml` | Reusable pre-merge gate | `workflow_call` |
| `cd.yml` | Local umbrella | `push` to main/develop |
| `cd-*.yml` | Reusable post-merge delivery | `workflow_call` |

**Bare category name** (`ci.yml`, `cd.yml`) = local consumer entry point.
**Category-subcategory** (`ci-quality.yml`, `cd-release.yml`) = reusable
workflow shared across the fleet.

### Consumer repo model

Each consumer repo has at most two workflow files:

- `ci.yml` — thin umbrella calling the `ci-*` reusable workflows
- `cd.yml` — thin umbrella calling the `cd-*` reusable workflows

Additional repo-specific workflow files are permitted but should be rare.

## standard-actions file changes

### Renames

| Current | New | Notes |
|---|---|---|
| `ci-release.yml` | `ci-version-bump.yml` | Reflects what it actually checks |
| `publish-release.yml` | `cd-release.yml` | CI/CD namespace alignment |
| `publish-docs.yml` | `cd-docs.yml` | Stripped of push trigger, workflow_call only |
| `publish.yml` | `cd.yml` | Local umbrella, absorbs push triggers |

### Unchanged

| File | Reason |
|---|---|
| `ci.yml` | Already correct (updated internally) |
| `ci-quality.yml` | Already follows convention |
| `ci-security.yml` | Already follows convention |
| `ci-test.yml` | Already follows convention |
| `ci-audit.yml` | Already follows convention |

### Internal updates to `ci.yml`

The caller job key changes from `release` to `version`, and the `uses:`
path updates from `ci-release.yml` to `ci-version-bump.yml`.

### `cd.yml` (new local umbrella)

Replaces `publish.yml`. Absorbs the push triggers that were previously
in `publish-docs.yml` (which had a dual push + workflow_call trigger).
Calls both `cd-release.yml` (push to main) and `cd-docs.yml` (push to
develop/main) as appropriate.

### `cd-docs.yml` (split from `publish-docs.yml`)

The current `publish-docs.yml` has both `push` and `workflow_call`
triggers. Under the new convention, `cd-docs.yml` becomes
workflow_call-only. The push trigger moves into the local `cd.yml`
umbrella. This matches the pattern: bare name is the local entry point,
hyphenated name is the reusable workflow.

### Workflow `name:` fields

| File | `name:` field |
|---|---|
| `ci-version-bump.yml` | `CI Version Bump` |
| `cd-release.yml` | `CD Release` |
| `cd-docs.yml` | `CD Docs` |
| `cd.yml` | `CD` |

## Check name changes

### CI gates (enforced via branch protection)

| Current | New |
|---|---|
| `quality / common` | *(unchanged)* |
| `quality / lint / <ver>` | *(unchanged)* |
| `quality / typecheck / <ver>` | *(unchanged)* |
| `security / trivy` | *(unchanged)* |
| `security / semgrep` | *(unchanged)* |
| `security / standards` | *(unchanged)* |
| `security / codeql` | *(unchanged)* |
| `test / unit / <ver>` | *(unchanged)* |
| `test / integration / <ver>` | *(unchanged)* |
| `audit / dependencies / <ver>` | *(unchanged)* |
| `release / version-bump` | `version / version-bump` |

The check name changes because the `ci.yml` caller job key changes from
`release` to `version`. The inner job name (`version-bump`) is unchanged.

### CD checks (informational, not enforced)

| Workflow | Check name |
|---|---|
| `cd-release.yml` | `cd / release` |
| `cd-docs.yml` | `cd / docs` |

These are produced by the consumer's `cd.yml` caller job keys and the
reusable workflow inner job names. They are post-merge and not part of
the CI gates ruleset.

## standard-tooling changes

### Check name registry

In `src/standard_tooling/lib/github_config.py`, the
`desired_ci_gates_ruleset()` function updates `release / version-bump`
to `version / version-bump`. All other check names are unchanged.

### Publish config references

The `PublishConfig` / `DesiredPublishConfig` data structures and any
code that references `publish-release.yml` or `publish-docs.yml`
filenames must be updated to use `cd-release.yml` and `cd-docs.yml`.

### standard-tooling's own workflows

| Current | New |
|---|---|
| `.github/workflows/publish-release.yml` | `.github/workflows/cd-release.yml` |
| `.github/workflows/publish-docs.yml` | `.github/workflows/cd-docs.yml` |

These are thin callers — rename files and update `uses:` references
to `standard-actions/.github/workflows/cd-release.yml@v1.5` and
`cd-docs.yml@v1.5`.

## Consumer repo changes

All 12 fleet repos receive a PR:

| # | Repo | Language |
|---|---|---|
| 1 | standard-actions | shell |
| 2 | standard-tooling | python |
| 3 | standard-tooling-docker | shell |
| 4 | standard-tooling-plugin | claude-plugin |
| 5 | mq-rest-admin-python | python |
| 6 | mq-rest-admin-go | go |
| 7 | mq-rest-admin-ruby | ruby |
| 8 | mq-rest-admin-java | java |
| 9 | mq-rest-admin-rust | rust |
| 10 | mq-rest-admin-common | shell |
| 11 | mq-rest-admin-dev-environment | shell |
| 12 | ai-research-methodology | python |

### Per-repo PR contents

1. Rename `publish-release.yml` → `cd-release.yml` (update `uses:`
   reference to `cd-release.yml@v1.5`)
2. Rename `publish-docs.yml` → `cd-docs.yml` (update `uses:` reference
   to `cd-docs.yml@v1.5`) — for repos that have docs
3. Merge publish callers into a single `cd.yml` umbrella
4. Update `ci.yml` caller job key from `release` to `version`, and
   `uses:` path from `ci-release.yml` to `ci-version-bump.yml`
5. Branch protection: update `release / version-bump` required status
   check to `version / version-bump`

## Rollout strategy

Approach C: big-bang with scripted rollout.

### Sequence

1. **standard-tooling code changes** — update check name registry,
   publish config references, release as a new standard-tooling version.
   This is a prerequisite; without it, the ruleset sync tool would
   fight the new check names.
2. **standard-actions ships renamed workflows** — v1.5.x release with
   all file renames and internal updates.
3. **Fleet sweep** — rollout script generates PRs for all 12 repos.
   Each PR includes the workflow renames and runs the updated
   standard-tooling ruleset sync to land branch protection changes.

### Rollout script

The script takes a repo name (or "all") and mechanically:

- Renames workflow files
- Updates `uses:` references
- Updates caller job keys
- Updates branch protection rules via `gh api`
- Creates a PR

### Manual scope

standard-tooling's Python code changes (check name registry, publish
config) are not in the script's scope — they ship as a separate commit
in the standard-tooling PR alongside its workflow renames.

Deployment race conditions between standard-tooling and standard-actions
releases may require temporary manual branch protection adjustments.
This is acceptable at current fleet scale (sole maintainer, 12 repos).

## Existing spec impact

The publish/docs rationalization spec
(`docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`)
established naming conventions using `publish-release.yml` and
`publish-docs.yml`. This spec supersedes those naming decisions.
The rationalization spec's architectural decisions (thin callers,
workflow_call interfaces, check name structure) remain valid — only
the `publish-*` → `cd-*` namespace changes.
