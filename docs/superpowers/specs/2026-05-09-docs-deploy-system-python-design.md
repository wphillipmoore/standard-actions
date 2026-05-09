# docs-deploy: Use system Python to avoid venv shadowing

**Issue:** [#418](https://github.com/wphillipmoore/standard-actions/issues/418)

**Status:** Approved

## Problem

The `docs-deploy` composite action fails with `ModuleNotFoundError: No
module named 'yaml'` when the calling repository is `standard-tooling`
itself.

The issue was initially diagnosed as PyYAML missing from the
`dev-base:latest` container image. Investigation showed that PyYAML *is*
installed in the image (added in `standard-tooling-docker` PR #109). The
actual root cause is PATH shadowing from a project virtual environment.

### Root cause

When `publish-docs.yml` runs against `standard-tooling`, the
`setup/standard-tooling` action detects that the consumer repo is
`standard-tooling` itself and runs `uv sync --frozen --group dev` to
install from source. This creates a `.venv/` with its own Python
interpreter and prepends `$GITHUB_WORKSPACE/.venv/bin` to `GITHUB_PATH`.

All subsequent `python3` calls resolve to the venv's interpreter, which
has only `standard-tooling`'s declared dependencies -- not the system
packages (`pyyaml`, `mkdocs-material`, etc.) that `dev-base` provides.

This is a corner case specific to `standard-tooling`: other consumer
repos use `uv tool install` instead, which does not create a venv or
modify `PATH` in the same way.

## Solution

Change the two inline `python3 -` invocations in
`actions/docs-deploy/action.yml` to use the absolute system Python path
(`/usr/local/bin/python3`). This bypasses any venv on `PATH` and reaches
the interpreter where `pyyaml` and the rest of the docs toolchain are
installed.

### Files changed

| File | Change |
|---|---|
| `actions/docs-deploy/action.yml` (line 82) | `python3 -` to `/usr/local/bin/python3 -` (release index script) |
| `actions/docs-deploy/action.yml` (line 125) | `python3 -` to `/usr/local/bin/python3 -` (nav-patching script) |

### Comments

Both call sites need a comment explaining why the absolute path is used.
Without it, the fully qualified path looks like an error -- the natural
expectation is bare `python3`. The comment should explain that the system
Python is required because project venvs (specifically `standard-tooling`
self-install) shadow it and lack the packages baked into `dev-base`.

### Scope

- Two lines changed, two comments added, one file.
- No changes to `dev-base`, `dev-python`, `standard-tooling`, or any
  caller workflow.
- No new dependencies or inputs.

### Constraints

- The path `/usr/local/bin/python3` is stable across all `dev-base` and
  `dev-python` images because they are all built `FROM python:*-slim`,
  which installs Python there.

## Issue update

The issue title should be updated to reflect the actual root cause (PATH
shadowing from project venv, not missing PyYAML in the container image).
