# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Documentation Strategy

This repository uses two complementary approaches for AI agent guidance:

- **AGENTS.md**: Generic AI agent instructions using include directives to force documentation indexing. Contains canonical standards references, shared skills loading, and user override support.
- **CLAUDE.md** (this file): Claude Code-specific guidance with prescriptive commands, architecture details, and development workflows optimized for `/init`.

<!-- include: docs/standards-and-conventions.md -->
<!-- include: docs/repository-standards.md -->

## Project Overview

This is a shared GitHub Actions library providing reusable composite actions for CI/CD across all managed repositories. Actions are consumed by pinning to a tag or branch reference.

**Project name**: standard-actions

**Status**: Pre-release (0.x)

**Canonical Standards**: This repository follows standards at <https://github.com/wphillipmoore/standards-and-conventions> (local path: `../standards-and-conventions` if available)

## Development Commands

### Environment Setup

- **Git hooks**: `git config core.hooksPath scripts/git-hooks` (required before committing)
- **markdownlint**: `npm install --global markdownlint-cli`
- **actionlint**: `brew install actionlint`
- **shellcheck**: `brew install shellcheck`

### Validation

```bash
scripts/dev/validate_local.sh    # Canonical validation (runs all checks below)
scripts/dev/validate_actions.sh  # actionlint + shellcheck
scripts/dev/validate_docs.sh     # markdownlint on docs/ and README.md
```

## Architecture

### Composite Actions

All actions live under `actions/` as composite GitHub Actions:

- `actions/docs-only-detect` — Detects documentation-only PRs to short-circuit expensive CI jobs
- `actions/standards-compliance` — Validates repo profile, markdown, commit messages, PR linkage, and shared tooling staleness
- `actions/python/setup` — Python environment setup with uv and caching
- `actions/security/codeql` — CodeQL static analysis
- `actions/security/semgrep` — Semgrep SAST scanning
- `actions/security/trivy` — Trivy vulnerability scanning (filesystem, SBOM, container image)

### Self-Referencing CI

This repository's CI workflow uses **local paths** (`./actions/...`) rather than remote references. This enables self-testing: changes to an action are validated by the same PR that modifies them.

### Sync Mechanism

Shared lint scripts in `actions/standards-compliance/scripts/` are kept synchronized with `standard-tooling` via `scripts/dev/sync-tooling.sh --actions-compat`. The standards-compliance action validates this staleness in consuming repos.

## Branching and PR Workflow

- **Protected branches**: `main`, `develop` — no direct commits (enforced by pre-commit hook)
- **Branch naming**: `feature/*`, `bugfix/*`, or `hotfix/*` only
- **Feature/bugfix PRs** target `develop` with squash merge: `gh pr merge --auto --squash --delete-branch`
- **Release PRs** target `main` with regular merge: `gh pr merge --auto --merge --delete-branch`
- **Pre-flight**: Always check branch with `git status -sb` before modifying files. If on `develop`, create a `feature/*` branch first.

## Commit and PR Scripts

**NEVER use raw `git commit`** — always use `scripts/dev/commit.sh`.
**NEVER use raw `gh pr create`** — always use `scripts/dev/submit-pr.sh`.

### Committing

```bash
scripts/dev/commit.sh --type feat --scope ci --message "add category prefixes" --agent claude
scripts/dev/commit.sh --type fix --message "correct action input name" --agent claude
scripts/dev/commit.sh --type docs --message "update README" --body "Expanded usage section" --agent claude
```

- `--type` (required): `feat|fix|docs|style|refactor|test|chore|ci|build`
- `--message` (required): commit description
- `--agent` (required): `claude` or `codex` — resolves the correct `Co-Authored-By` identity
- `--scope` (optional): conventional commit scope
- `--body` (optional): detailed commit body

### Submitting PRs

```bash
scripts/dev/submit-pr.sh --issue 42 --summary "Add category prefixes to CI job names"
scripts/dev/submit-pr.sh --issue 42 --linkage Ref --summary "Update docs" --docs-only
scripts/dev/submit-pr.sh --issue 42 --summary "Fix action input" --notes "Tested locally"
```

- `--issue` (required): GitHub issue number (just the number)
- `--summary` (required): one-line PR summary
- `--linkage` (optional, default: `Fixes`): `Fixes|Closes|Resolves|Ref`
- `--title` (optional): PR title (default: most recent commit subject)
- `--notes` (optional): additional notes
- `--docs-only` (optional): applies docs-only testing exception
- `--dry-run` (optional): print generated PR without executing

## Key References

**Canonical Standards**: <https://github.com/wphillipmoore/standards-and-conventions>

- Local path (preferred): `../standards-and-conventions`
- Load all skills from: `<standards-repo-path>/skills/**/SKILL.md`

**User Overrides**: `~/AGENTS.md` (optional, applied if present and readable)
