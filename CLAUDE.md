# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

<!-- include: docs/standards-and-conventions.md -->
<!-- include: docs/repository-standards.md -->

## Auto-memory policy

**Do NOT use MEMORY.md.** Never write to MEMORY.md or any file under the
memory directory. All behavioral rules, conventions, and workflow instructions
belong in managed, version-controlled documentation (CLAUDE.md, AGENTS.md,
skills, or docs/). If you want to persist something, tell the human what you
would save and let them decide where it belongs.

## Project Overview

This is a shared GitHub Actions library providing reusable composite actions for CI/CD across all managed repositories. Actions are consumed by pinning to a tag or branch reference.

**Project name**: standard-actions

**Status**: Pre-release (0.x)

**Canonical Standards**: This repository follows standards at <https://github.com/wphillipmoore/standards-and-conventions> (local path: `../standards-and-conventions` if available)

## Development Commands

### Environment Setup

```bash
git config core.hooksPath ../standard-tooling/scripts/lib/git-hooks  # Enable git hooks
```

Standard-tooling CLI tools (`st-commit`, `st-validate-local`, etc.) are
pre-installed in the dev container images. No local setup required.

Additional tools required:

- **markdownlint**: `npm install --global markdownlint-cli`
- **mkdocs-material**: `pip install mkdocs-material`
- **mike**: `pip install mike`
- **actionlint**: `brew install actionlint`
- **shellcheck**: `brew install shellcheck`

### Validation

```bash
st-validate-local    # Canonical validation (dispatches to common + custom checks)
```

## Architecture

### Composite Actions

All actions live under `actions/` as composite GitHub Actions:

- `actions/standards-compliance` — Validates repo profile, markdown, commit messages, and PR linkage (delegates to standard-tooling validators via PATH)
- `actions/python/setup` — Python environment setup with uv and caching
- `actions/security/codeql` — CodeQL static analysis
- `actions/security/semgrep` — Semgrep SAST scanning
- `actions/security/trivy` — Trivy vulnerability scanning (filesystem, SBOM, container image)

### Self-Referencing CI

This repository's CI workflow uses **local paths** (`./actions/...`) rather than remote references. This enables self-testing: changes to an action are validated by the same PR that modifies them.

### Standard-Tooling Integration

Shared validators (`repo-profile`, `markdown-standards`, `commit-messages`, `pr-issue-linkage`) are provided by `standard-tooling` via PATH. The `standards-compliance` action checks out `standard-tooling` and prepends its `scripts/bin/` to `$GITHUB_PATH`. Locally, the same tools are available by adding `../standard-tooling/scripts/bin` to your PATH.

### Repo-Specific Scripts

```
scripts/
└── bin/
    └── validate-local-custom    # actionlint (repo-specific)
```
