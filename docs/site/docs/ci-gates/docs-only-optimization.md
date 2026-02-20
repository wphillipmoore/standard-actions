# Docs-Only Optimization

## How it works

The [docs-only-detect](../actions/docs-only-detect.md) action examines the list
of files changed in a pull request and determines whether all changes are
documentation-only. When a PR is docs-only, expensive CI jobs (builds, tests,
security scans) are skipped to reduce feedback time and CI cost.

## Default docs patterns

The default patterns match these files:

```text
docs/**
README.md
CHANGELOG.md
*.md
```

These patterns can be customized per-repository using the `docs-patterns` input.

## Which jobs are gated vs. always-run

| Job | Docs-only behavior |
| ----- | ------------------- |
| `ci: docs-only` | Always runs (this is the detection job itself) |
| `ci: standards-compliance` | **Always runs** — markdown linting and repo profile checks apply to docs changes |
| `ci: dependency-audit` | **Always runs** — not gated by docs-only |
| `ci: actionlint` | Skipped on docs-only PRs |
| `ci: shellcheck` | Skipped on docs-only PRs |
| `test: unit` | Skipped on docs-only PRs |
| `test: integration` | Skipped on docs-only PRs |
| `security: codeql` | Skipped on docs-only PRs |
| `security: semgrep` | Skipped on docs-only PRs |
| `security: trivy` | Skipped on docs-only PRs |
| `release: gates` | **Always runs** — not gated by docs-only |

## Implementation pattern

The docs-only detection runs as the first job and exports its result as a job
output. Downstream jobs declare `needs: docs-only` and guard each step with the
docs-only condition:

```yaml
jobs:
  docs-only:
    name: "ci: docs-only"
    runs-on: ubuntu-latest
    outputs:
      docs-only: ${{ steps.detect.outputs.docs-only }}
    steps:
      - uses: actions/checkout@v6
      - id: detect
        uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop

  codeql:
    name: "security: codeql"
    runs-on: ubuntu-latest
    needs: docs-only
    permissions:
      security-events: write
    steps:
      - name: Docs-only short-circuit
        if: needs.docs-only.outputs.docs-only == 'true'
        run: echo "Docs-only changes detected; skipping CodeQL."

      - name: Checkout code
        if: needs.docs-only.outputs.docs-only != 'true'
        uses: actions/checkout@v6

      - name: Run CodeQL analysis
        if: needs.docs-only.outputs.docs-only != 'true'
        uses: wphillipmoore/standard-actions/actions/security/codeql@develop
        with:
          language: python
```

!!! warning "Per-step guards, not job-level `if`"
    Jobs that are required status checks must still **run** on docs-only PRs —
    they cannot be skipped entirely with a job-level `if` condition. Instead,
    each step within the job is guarded by the docs-only condition. This ensures
    GitHub sees the check as passing. A job-level `if: false` causes the job to
    be "skipped", which does not satisfy required status checks.
