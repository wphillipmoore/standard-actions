# Required Checks

## Check matrix

The following table shows which CI checks apply to each repository category.
Checks marked **Required** must be configured as required status checks in the
[CI gates ruleset](repository-rulesets.md#ci-gates-ruleset).

| Check | Go Library | Python Library | Ruby Library | Java Library | Infrastructure | Documentation |
| ------- | ----------- | --------------- | ------------- | ------------- | ---------------- | --------------- |
| `ci: standards-compliance` | Required | Required | Required | Required | Required | Required |
| `ci: dependency-audit` | Required | Required | Required | Required | — | — |
| `ci: actionlint` | — | — | — | — | Required | — |
| `ci: shellcheck` | — | — | — | — | Required | — |
| `test: unit` | Required | Required | Required | Required | — | — |
| `test: integration` | Required | Required | Required | Required | — | — |
| `security: codeql` | Required | Required | Required | Required | — | — |
| `security: semgrep` | Required | Required | Required | Required | — | — |
| `security: trivy` | Required | Required | Required | Required | — | — |
| `release: gates` | Required | Required | Required | Required | — | — |

### Matrix-expanded check names

Both `test: unit` and `test: integration` appear once per version in the
language matrix. Each matrix expansion is a separate required check in the
CI gates ruleset.

| Repository | `test: unit` checks | `test: integration` checks |
| ------------ | --------------------- | ---------------------------- |
| mq-rest-admin-go | `test: unit (1.25)`, `test: unit (1.26)` | `test: integration (1.25)`, `test: integration (1.26)` |
| mq-rest-admin-python | `test: unit (3.12)`, `test: unit (3.13)`, `test: unit (3.14)` | `test: integration (3.12)`, `test: integration (3.13)`, `test: integration (3.14)` |
| mq-rest-admin-ruby | `test: unit (3.2)`, `test: unit (3.3)`, `test: unit (3.4)` | `test: integration (3.2)`, `test: integration (3.3)`, `test: integration (3.4)` |

## Job name prefix convention

All CI job names use a category prefix followed by a colon and the job name.
This convention enables clear identification in the GitHub checks UI and
supports pattern-based branch protection rules.

```yaml
jobs:
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
