# Required Checks

## Check matrix

The following table shows which CI checks apply to each repository category.
Checks marked **Required** must be configured as required status checks in
GitHub branch protection rules.

| Check | Go Library | Python Library | Java Library | Infrastructure | Documentation |
| ------- | ----------- | --------------- | ------------- | ---------------- | --------------- |
| `ci: docs-only` | Required | Required | Required | Required | Required |
| `ci: standards-compliance` | Required | Required | Required | Required | Required |
| `ci: dependency-audit` | Required | Required | Required | — | — |
| `ci: actionlint` | — | — | — | Required | — |
| `ci: shellcheck` | — | — | — | Required | — |
| `test: unit` | Required | Required | Required | — | — |
| `test: integration` | Required | Required | Required | — | — |
| `security: codeql` | Required | Required | Required | — | — |
| `security: semgrep` | Required | Required | Required | — | — |
| `security: trivy` | Required | Required | Required | — | — |
| `release: gates` | Required | Required | Required | — | — |

## Job name prefix convention

All CI job names use a category prefix followed by a colon and the job name.
This convention enables clear identification in the GitHub checks UI and
supports pattern-based branch protection rules.

```yaml
jobs:
  docs-only:
    name: "ci: docs-only"
  standards:
    name: "ci: standards-compliance"
  unit-tests:
    name: "test: unit"
  codeql:
    name: "security: codeql"
  release-gates:
    name: "release: gates"
```

## Branch protection configuration

### develop branch

All checks from the matrix should be configured as required status checks.
Enable:

- **Require status checks to pass before merging**
- **Require branches to be up to date before merging**
- **Require pull request reviews before merging** (at least 1 approval)

### main branch

The `main` branch uses the same required checks as `develop`. Additionally:

- **Require linear history** should be disabled (merge commits from release PRs
  are expected)
- **Allow merge commits** must be enabled for release PRs

## Adding new required checks

When adding a new check to a repository:

1. Add the job to the CI workflow with the appropriate name prefix.
2. Verify the check passes on a test PR.
3. Add the check name to the branch protection required status checks list in
   repository settings.
