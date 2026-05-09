# Normalize st-* Command Availability Design

**Issue:** [#403 — fix: normalize st-* command availability across install paths in setup/standard-tooling](https://github.com/wphillipmoore/standard-actions/issues/403)

**Date:** 2026-05-09

**Status:** Ready for implementation

## Problem

The `setup/standard-tooling` composite action has two install paths that
leave `st-*` commands in different locations:

- **Consumer repos:** `uv tool install "standard-tooling @ ..."` installs
  `st-*` binaries to the system tool path. Commands are on PATH. Works
  everywhere.
- **Standard-tooling itself (self-install):** `uv sync --frozen --group dev`
  installs into `.venv/bin/`, which is not on PATH. Commands require either
  PATH manipulation or `uv run` to invoke.

This inconsistency forces downstream workflows to apply per-call-site PATH
workarounds, and files that omit the workaround break when consumed by the
standard-tooling repository. This is blocking the standard-tooling v1.4.29
release.

### Current state

**Pattern 1 — per-step PATH workaround (5 call sites):**

Each step that invokes `st-*` prepends `$GITHUB_WORKSPACE/.venv/bin` to
PATH inline. Four of the five files carry a multi-line comment block
(referencing issue #362) explaining the workaround.

| File | Workaround |
|------|-----------|
| `.github/workflows/ci-audit.yml` | Comment block + PATH line |
| `.github/workflows/ci-quality.yml` | Comment block + 3 PATH lines |
| `.github/workflows/ci-test.yml` | Comment block + PATH line |
| `actions/standards-compliance/action.yml` | PATH line (no comment) |
| `actions/release-gates/version-divergence/action.yml` | PATH line (no comment) |

**Pattern 2 — no workaround (4 call sites):**

These call `st-*` directly. They work for consumer repos but fail for
standard-tooling itself.

| File | Broken command |
|------|---------------|
| `.github/workflows/publish.yml` | `st-version show` |
| `.github/workflows/publish-release.yml` | `st-version show` |
| `.github/workflows/ci-release.yml` | `st-version show` / `st-version show --ref` |
| `actions/publish/version-bump-pr/action.yml` | `st-version show` / `st-version bump` |

## Rejected approaches

### Use `uv tool install .` for self-install

This would put `st-*` on the system tool path for both install paths.
Rejected because standard-tooling's CI must dog-food the venv — tests, lint,
and type-checking run against the development environment, not an installed
snapshot.

### Replicate Pattern 1 to all call sites

Adding `PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"` to every step that invokes
`st-*` would fix Pattern 2 files, but scatters environment-specific
workarounds across every call site. The existing comment blocks documenting
this workaround are a smell, not a pattern to replicate.

### Use `uv run` for all invocations

`uv run st-version show` finds `.venv/bin` automatically, but does not work
for non-Python consumer repos that have no `pyproject.toml`.

## Chosen approach: GITHUB_PATH in the setup action

### Mechanism

`$GITHUB_PATH` is a GitHub Actions runner feature for inter-step PATH
modification. It is not environment variable inheritance — it is file-based
IPC:

1. Before each step, the runner creates a temporary file and exports its path
   as `$GITHUB_PATH`.
2. When a step runs `echo "/some/dir" >> "$GITHUB_PATH"`, it appends a line
   to that file.
3. After the step exits, the runner (the parent process) reads the file and
   prepends the entries to `PATH` for all subsequent steps.

This sidesteps the UNIX constraint that a child process cannot modify its
parent's environment. Because `$GITHUB_WORKSPACE` resolves to the runner's
actual workspace mount point (`/__w/<repo>/<repo>`), this also eliminates the
container WORKDIR mismatch described in the existing comment blocks (issue
#362): the Docker image bakes `/workspace/.venv/bin` into PATH, but GitHub
Actions mounts the workspace elsewhere, so that entry never resolves.

### Change to the setup action

In `actions/setup/standard-tooling/action.yml`, add one line to the
self-install branch:

```yaml
- name: Install standard-tooling
  shell: bash
  run: |
    if grep -q '^name = "standard-tooling"' pyproject.toml 2>/dev/null; then
      echo "Consumer repo is standard-tooling itself — installing from source"
      uv sync --frozen --group dev
      echo "$GITHUB_WORKSPACE/.venv/bin" >> "$GITHUB_PATH"
      exit 0
    fi

    TAG=$(sed -n 's/^[[:space:]]*standard-tooling[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' standard-tooling.toml)
    if [ -z "${TAG:-}" ]; then
      echo "::error::standard-tooling.toml not found or missing version tag"
      exit 1
    fi
    uv tool install "standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@${TAG}"
```

After this step completes, `st-*` commands (and dev tools such as ruff, mypy,
pytest, pip-audit) are on PATH for every subsequent step in the job.

### Cleanup: remove per-call-site workarounds

With the fix centralized in the setup action, all existing per-step PATH
workarounds become dead code. Remove them:

| File | Remove |
|------|--------|
| `.github/workflows/ci-audit.yml` | 6-line comment block (lines 1-6), `PATH=...` line |
| `.github/workflows/ci-quality.yml` | 6-line comment block (lines 1-6), 3 `PATH=...` lines |
| `.github/workflows/ci-test.yml` | 6-line comment block (lines 1-6), `PATH=...` line |
| `actions/standards-compliance/action.yml` | `PATH=...` line |
| `actions/release-gates/version-divergence/action.yml` | `PATH=...` line |

Pattern 2 files require **no changes** — they already call `st-*` directly,
and the setup action now ensures that works.

## Scope

### In scope

- One-line addition to `actions/setup/standard-tooling/action.yml`
- Removal of PATH workaround lines and comment blocks from 5 files

### Out of scope

- Consumer repo behavior (unaffected — they take the `uv tool install`
  branch, which already puts `st-*` on PATH)
- The `uv sync --frozen --group dev` install mechanism
- Workflow structure or step ordering
- Any changes to the standard-tooling repository itself

## Validation

After applying the fix, the standard-tooling repository's CI workflows (which
consume these reusable workflows) should pass without any per-step PATH
manipulation. The immediate validation is that the standard-tooling v1.4.29
publish workflow succeeds at the `st-version show` step that currently fails.
Additionally, the standard-tooling CI quality workflow (ci-quality.yml) —
which currently uses per-step PATH workarounds in its lint, typecheck, and
format jobs — should pass without them after the setup action change.
