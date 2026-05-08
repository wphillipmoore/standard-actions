# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

**Standards reference**: <https://github.com/wphillipmoore/standards-and-conventions>
— active standards documentation lives in the standard-tooling repository under `docs/`.
Repository profile: `standard-tooling.toml`.

## Memory management

Memory is allowed with human approval. The authoritative policy is in
the user's global `~/.claude/CLAUDE.md` — agents must propose memory
writes and suggest a destination (repo memory, global CLAUDE.md, or
plugin/skill issue) before writing. See that file for the full
workflow.

Available skills:

- `/standard-tooling:memory-init` — set up or update the policy header
  in a project's `MEMORY.md`.
- `/standard-tooling:memory-audit` — structured collaborative review
  of memory files.

## Parallel AI agent development

This repository supports running multiple Claude Code agents in parallel via
git worktrees. The convention keeps parallel agents' working trees isolated
while preserving shared project memory (which Claude Code derives from the
session's starting CWD).

**Canonical spec:**
[`standard-tooling/docs/specs/worktree-convention.md`](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/specs/worktree-convention.md)
— full rationale, trust model, failure modes, and memory-path implications.
The canonical text lives in `standard-tooling`; this section is the local
on-ramp.

### Structure

```text
~/dev/github/standard-actions/           ← sessions ALWAYS start here
  .git/
  CLAUDE.md, actions/, …                 ← main worktree (usually `develop`)
  .worktrees/                            ← container for parallel worktrees
    issue-183-adopt-worktree-convention/ ← worktree on feature/183-...
    …
```

### Rules

1. **Sessions always start at the project root.**
   `cd ~/dev/github/standard-actions && claude` — never from inside
   `.worktrees/<name>/`. This keeps the memory-path slug stable and shared.
2. **Each parallel agent is assigned exactly one worktree.** The session
   prompt names the worktree (see Agent prompt contract below).
   - For Read / Edit / Write tools: use the worktree's absolute path.
   - For Bash commands that touch files: `cd` into the worktree first,
     or use absolute paths.
3. **The main worktree is read-only.** All edits flow through a worktree
   on a feature branch — the logical endpoint of the standing
   "no direct commits to develop" policy.
4. **One worktree per issue.** Don't stack in-flight issues. When a
   branch lands, remove the worktree before starting the next.
5. **Naming: `issue-<N>-<short-slug>`.** `<N>` is the GitHub issue
   number; `<short-slug>` is 2–4 kebab-case tokens.

### Agent prompt contract

When launching a parallel-agent session, use this template (fill in the
placeholders):

```text
You are working on issue #<N>: <issue title>.

Your worktree is: /Users/pmoore/dev/github/standard-actions/.worktrees/issue-<N>-<slug>/
Your branch is:   feature/<N>-<slug>

Rules for this session:
- Do all git operations from inside your worktree:
    cd <absolute-worktree-path> && git <command>
- For Read / Edit / Write tools, use the absolute worktree path.
- For Bash commands that touch files, cd into the worktree first
  or use absolute paths.
- Do not edit files at the project root. The main worktree is
  read-only — all changes flow through your worktree on your
  feature branch.
```

All fields are required.

## Project Overview

This is a shared GitHub Actions library providing reusable composite actions
for CI/CD across all managed repositories. Actions are consumed by pinning
to a tag or branch reference.

**Project name**: standard-actions

**Status**: v1.x (stable)

**Canonical Standards**: This repository follows standards at
<https://github.com/wphillipmoore/standards-and-conventions>
(local path: `../standards-and-conventions` if available)

## Development Commands

### Environment Setup

```bash
git config core.hooksPath .githooks  # Enable the pre-commit gate
```

Standard-tooling CLI tools (`st-commit`, `st-validate`, etc.) are
pre-installed in the dev container images. No local setup required beyond
the host-level tool (`st-docker-run`, `st-commit`, etc.):

```bash
uv tool install 'standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@v1.4'
```

All validation tools (yamllint, shellcheck, actionlint, markdownlint, etc.)
run inside the `ghcr.io/wphillipmoore/dev-base:latest` container — no manual
host installs needed.

### Validation

```bash
st-docker-run -- st-validate   # Canonical validation (runs in dev-base container)
```

## Architecture

### Composite Actions

All actions live under `actions/` as composite GitHub Actions:

- `actions/standards-compliance` — PR-specific compliance checks: issue
  linkage and auto-close keyword rejection
- `actions/python/setup` — Python environment setup with uv and caching
- `actions/security/codeql` — CodeQL static analysis
- `actions/security/semgrep` — Semgrep SAST scanning
- `actions/security/trivy` — Trivy vulnerability scanning (filesystem,
  SBOM, container image)

### Self-Referencing CI

This repository's CI workflow uses **local paths** (`./actions/...`)
rather than remote references. This enables self-testing: changes to an
action are validated by the same PR that modifies them.

### Standard-Tooling Integration

Shared validators (`st-repo-profile`, `st-pr-issue-linkage`) and local
validation (`st-validate`) are provided by `standard-tooling`. CI uses
the `ghcr.io/wphillipmoore/dev-base:latest` container image which has all
validators pre-installed. Locally, `st-docker-run` uses the same image so
validation results match CI exactly.

### Validation

All validation — including actionlint — is handled by `st-validate` via the
built-in command registry. No repo-specific validation scripts are needed.
