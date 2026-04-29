# Standard Actions

Shared GitHub Actions library providing reusable composite actions for CI/CD
across all managed repositories.

## Status

**Stable (v1.x)** — Actions are consumed by pinning to a rolling minor tag
(e.g., `@v1.4`), which automatically receives patch releases.

## Action categories

| Category | Actions | Purpose |
| ---------- | --------- | --------- |
| CI & Validation | [standards-compliance](actions/standards-compliance.md) | PR validation and standards enforcement |
| Documentation | [docs-deploy](actions/docs-deploy.md) | MkDocs Material + mike versioned deployment |
| Python | [python/setup](actions/python-setup.md) | Python environment with uv and caching |
| Security | [security/codeql](actions/security-codeql.md), [security/semgrep](actions/security-semgrep.md), [security/trivy](actions/security-trivy.md) | SAST and vulnerability scanning |
| Publishing | [publish/tag-and-release](actions/publish-tag-and-release.md), [publish/version-bump-pr](actions/publish-version-bump-pr.md) | Release tagging and post-release version bumps |
| Release Gates | [release-gates/version-divergence](actions/release-gates-version-divergence.md) | Pre-merge version validation |

## Design principles

- **Composite actions only** — No custom JavaScript or Docker actions. Every
  action is a composite `action.yml` with shell steps.
- **Self-referencing CI** — This repository's own CI uses `./actions/...` local
  paths, so changes to an action are tested by the same PR that modifies them.
- **Centralized standards** — Workflow patterns and validation rules are defined
  once here and consumed by all repositories.

## Canonical standards

This repository follows the
[Standards and Conventions](https://github.com/wphillipmoore/standards-and-conventions)
repository for commit messages, branching, versioning, and code management
practices.
