# ci-security

Standards compliance and security scanning workflow.

## Inputs

| Input | Type | Required | Default | Description |
| ------- | ------ | ---------- | --------- | ------------- |
| `language` | string | yes | — | Language for security scanners (e.g., `python`, `go`, `ruby`) |
| `run-standards` | boolean | no | `true` | Run the standards-compliance job |
| `run-security` | boolean | no | `true` | Run security scanner jobs (CodeQL, Semgrep, Trivy) |
| `run-codeql` | boolean | no | `true` | Run CodeQL analysis (disable for unsupported languages like `shell`) |

## Required permissions

```yaml
permissions:
  contents: read
  security-events: write
```

## Jobs and check names

| Job | Check name | Condition |
| ----- | ------------ | ----------- |
| `standards` | `CI Security / standards` | `run-standards` is true |
| `codeql` | `CI Security / codeql` | `run-security` and `run-codeql` are true |
| `trivy` | `CI Security / trivy` | `run-security` is true |
| `semgrep` | `CI Security / semgrep` | `run-security` is true |

## Usage

```yaml
jobs:
  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: python
```

To skip CodeQL for languages it does not support:

```yaml
jobs:
  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: shell
      run-codeql: false
```

## Implementation notes

- The `standards` and `semgrep` jobs run inside the
  `ghcr.io/wphillipmoore/dev-base:latest` container.
- The `standards` job installs `standard-tooling` from the version pinned in
  `standard-tooling.toml` (with a legacy `st-config.toml` fallback).
- For Python repositories, the `standards` job runs `uv sync --group dev --frozen`
  to make project-installed tools available on `PATH`.
