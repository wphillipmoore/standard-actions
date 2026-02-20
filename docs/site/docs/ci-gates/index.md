# CI Gate Requirements

This section defines the target-state CI gate specification for repositories
consuming standard-actions. It documents which checks are required, how they
interact with docs-only optimization, and the security scanning requirements.

## Overview

Every managed repository runs a common set of CI checks on pull requests and
pushes to protected branches. These checks are organized by category using job
name prefixes:

| Prefix | Purpose | Example jobs |
| -------- | --------- | ------------- |
| `ci:` | Code quality and standards validation | `ci: standards-compliance`, `ci: actionlint` |
| `security:` | SAST and vulnerability scanning | `security: codeql`, `security: semgrep` |
| `test:` | Unit and integration tests | `test: unit`, `test: integration` |
| `release:` | Release gate validations | `release: version-divergence` |

## Key concepts

- **Required status checks** — Configured in GitHub branch protection rules.
  PRs cannot merge until all required checks pass.
- **Docs-only optimization** — Documentation-only PRs skip expensive checks
  (builds, tests, security scans) while still running standards compliance.
- **Self-referencing CI** — The standard-actions repository tests its own
  actions using local paths (`./actions/...`).

## Pages in this section

- [Required Checks](required-checks.md) — Matrix of checks by repository
  category
- [Docs-Only Optimization](docs-only-optimization.md) — How docs-only detection
  works and which jobs are gated
- [Security Scanning](security-scanning.md) — CodeQL, Semgrep, and Trivy
  configuration details
