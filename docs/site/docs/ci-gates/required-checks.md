# Required Checks

## Check matrix

The following table shows which CI checks apply to each repository category.
Checks marked **Required** must be configured as required status checks in the
[CI gates ruleset](repository-rulesets.md#ci-gates-ruleset).

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

## Ruleset configuration

All required status checks are enforced via GitHub repository rulesets, not
legacy branch protection rules. Both `main` and `develop` are covered by the
same CI gates ruleset. See [Repository Rulesets](repository-rulesets.md) for
full configuration details including branch protection, CI gates, and tag
protection.
