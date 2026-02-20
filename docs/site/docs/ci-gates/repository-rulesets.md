# Repository Rulesets

## Overview

All managed repositories use GitHub's **repository rulesets** (not legacy branch
protection rules) to enforce merge requirements. Every repository has the same
three rulesets:

| Ruleset | Target | Purpose |
| --------- | -------- | --------- |
| Branch protection | `main`, `develop` | PR requirements, deletion and force-push prevention |
| CI gates | `main`, `develop` | Required status checks |
| Tag protection | `v*` tags | Prevent tag deletion, update, and non-fast-forward |

## Branch protection ruleset

Applies to both `main` and `develop` branches across all repositories.

| Setting | Value |
| --------- | ------- |
| Require pull request | Yes |
| Required approving review count | 0 |
| Dismiss stale reviews on push | Yes |
| Require code owner review | No |
| Require last push approval | No |
| Require review thread resolution | No |
| Allowed merge methods | merge, squash, rebase |
| Block deletion | Yes |
| Block non-fast-forward | Yes |
| Bypass actors | None (`current_user_can_bypass: never`) |

!!! note "Zero required approvals"
    The required approving review count is set to 0. PRs still require a pull
    request (direct pushes are blocked), but self-approval is permitted. This is
    appropriate for single-maintainer repositories.

## CI gates ruleset

Applies to both `main` and `develop` branches. Contains the required status
checks that must pass before a PR can merge.

| Setting | Value |
| --------- | ------- |
| Strict required status checks | Yes (branch must be up to date) |
| Do not enforce on create | No |

The required checks vary by repository category. See the
[check matrix](required-checks.md#check-matrix) for the full list.

### Library repositories (Go, Python, Java)

```text
ci: docs-only
ci: standards-compliance
ci: dependency-audit
release: gates
test: unit (per matrix version)
test: integration
security: codeql
security: semgrep
security: trivy
```

!!! note "Matrix-expanded check names"
    The `test: unit` check appears once per matrix version. For example,
    mq-rest-admin-go requires `test: unit (1.25)` and `test: unit (1.26)`.
    Each matrix expansion is a separate required check.

### Infrastructure repositories

```text
ci: docs-only
ci: standards-compliance
ci: shellcheck
```

The standard-actions repository additionally requires `ci: actionlint`.

### Documentation repositories

```text
ci: docs-only
ci: standards-compliance
```

## Tag protection ruleset

Applies to all tags matching `v*`. Prevents unauthorized modification of release
tags.

| Setting | Value |
| --------- | ------- |
| Block deletion | Yes |
| Block non-fast-forward | Yes |
| Block update | Yes |
| Bypass actors | None |

## Adding a new required check

When adding a new CI job that should block merges:

1. Add the job to the CI workflow with the appropriate
   [name prefix](required-checks.md#job-name-prefix-convention).
2. Open a PR and verify the check runs and passes.
3. After the PR merges, add the exact check name to the CI gates ruleset via
   **Settings > Rules > Rulesets > CI gates**.
4. Verify the check name matches exactly — matrix-expanded names like
   `test: unit (3.14)` must be added individually.

## Modifying rulesets via API

Rulesets can be updated programmatically using the GitHub API:

```bash
# List rulesets for a repository
gh api repos/wphillipmoore/{repo}/rulesets \
  --jq '.[] | {id: .id, name: .name}'

# View a specific ruleset
gh api repos/wphillipmoore/{repo}/rulesets/{id}

# Update required status checks
gh api --method PUT repos/wphillipmoore/{repo}/rulesets/{id} \
  --input payload.json
```
