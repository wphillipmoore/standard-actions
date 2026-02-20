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
| `ci: actionlint` | Skipped on docs-only PRs |
| `ci: shellcheck` | Skipped on docs-only PRs |
| `test: unit` | Skipped on docs-only PRs |
| `test: integration` | Skipped on docs-only PRs |
| `security: codeql` | Skipped on docs-only PRs |
| `security: semgrep` | Skipped on docs-only PRs |
| `security: trivy` | Skipped on docs-only PRs |
| `release: version-divergence` | Skipped on docs-only PRs |

## Implementation pattern

The docs-only detection runs as the first job and exports its result as a job
output. Downstream jobs depend on this output:

```yaml
jobs:
  docs-only:
    runs-on: ubuntu-latest
    outputs:
      docs-only: ${{ steps.detect.outputs.docs-only }}
    steps:
      - uses: actions/checkout@v6
      - id: detect
        uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop

  build:
    needs: docs-only
    runs-on: ubuntu-latest
    steps:
      - if: needs.docs-only.outputs.docs-only == 'true'
        run: echo "Docs-only changes; skipping."
      - if: needs.docs-only.outputs.docs-only != 'true'
        uses: actions/checkout@v6
      # ... remaining steps guarded by the same condition
```

!!! note "Required checks and docs-only"
    Jobs that are required status checks must still **run** on docs-only PRs
    (they cannot be skipped entirely with an `if` on the job). Instead, each
    step within the job is guarded by the docs-only condition. This ensures
    GitHub sees the check as passing.

## Non-PR events

For push events (e.g., pushes to `develop`), docs-only detection always returns
`false`. All checks run on non-PR events regardless of the files changed.
