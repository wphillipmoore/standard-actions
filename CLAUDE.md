# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Auto-memory policy

**Do NOT use MEMORY.md.** Claude Code's auto-memory feature stores behavioral
rules outside of version control, making them invisible to code review,
inconsistent across repos, and unreliable across sessions. All behavioral rules,
conventions, and workflow instructions belong in managed, version-controlled
documentation (CLAUDE.md, AGENTS.md, skills, or docs/).

If you identify a pattern, convention, or rule worth preserving:

1. **Stop.** Do not write to MEMORY.md.
2. **Discuss with the user** what you want to capture and why.
3. **Together, decide** the correct managed location (CLAUDE.md, a skill file,
   standards docs, or a new issue to track the gap).

This policy exists because MEMORY.md is per-directory and per-machine — it
creates divergent agent behavior across the multi-repo environment this project
operates in. Consistency requires all guidance to live in shared, reviewable
documentation.

## Shell command policy

**Do NOT use heredocs** (`<<EOF` / `<<'EOF'`) for multi-line arguments to CLI
tools such as `gh`, `git commit`, or `curl`. Heredocs routinely fail due to
shell escaping issues with apostrophes, backticks, and special characters.
Always write multi-line content to a temporary file and pass it via `--body-file`
or `--file` instead.

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

```bash
cd ../standard-tooling && uv sync                                                # Install standard-tooling
export PATH="../standard-tooling/.venv/bin:../standard-tooling/scripts/bin:$PATH" # Put tools on PATH
git config core.hooksPath ../standard-tooling/scripts/lib/git-hooks               # Enable git hooks
```

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

- `actions/docs-only-detect` — Detects documentation-only PRs to short-circuit expensive CI jobs
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

## Branching and PR Workflow

- **Protected branches**: `main`, `develop` — no direct commits (enforced by pre-commit hook)
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, or `release/*` only
- **Feature/bugfix PRs** target `develop` with squash merge: `gh pr merge --auto --squash --delete-branch`
- **Release PRs** target `main` with regular merge: `gh pr merge --auto --merge --delete-branch`
- **Pre-flight**: Always check branch with `git status -sb` before modifying files. If on `develop`, create a `feature/*` branch first.

## Commit and PR Scripts

**NEVER use raw `git commit`** — always use `st-commit`.
**NEVER use raw `gh pr create`** — always use `st-submit-pr`.

### Committing

```bash
st-commit --type feat --scope ci --message "add category prefixes" --agent claude
st-commit --type fix --message "correct action input name" --agent claude
st-commit --type docs --message "update README" --body "Expanded usage section" --agent claude
```

- `--type` (required): `feat|fix|docs|style|refactor|test|chore|ci|build`
- `--message` (required): commit description
- `--agent` (required): `claude` or `codex` — resolves the correct `Co-Authored-By` identity
- `--scope` (optional): conventional commit scope
- `--body` (optional): detailed commit body

### Submitting PRs

```bash
st-submit-pr --issue 42 --summary "Add category prefixes to CI job names"
st-submit-pr --issue 42 --linkage Ref --summary "Update docs" --docs-only
st-submit-pr --issue 42 --summary "Fix action input" --notes "Tested locally"
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
