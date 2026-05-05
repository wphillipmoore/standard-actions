# CI Workflow Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace stub CI reusable workflows with real implementations
driven by a centralized `st-validate` command that reads from the
command registry in standard-tooling.

**Architecture:** Three sequential phases — (1) build `st-validate` CLI
and fix the command registry in standard-tooling, (2) implement reusable
CI workflows in standard-actions, (3) roll out thin callers across the
fleet. Each phase produces a releasable artifact before the next begins.

**Tech Stack:** Python 3.12+ (standard-tooling CLI), GitHub Actions YAML
(reusable workflows), TOML (configuration)

**Spec:** `docs/specs/2026-05-05-ci-workflow-reset-design.md`

**Coordination:** Phase 1 is combined with the publish-and-docs
rationalization spec (#318). Both specs' standard-tooling work ships in
a single release.

---

## Phase 1: standard-tooling foundations

> **Repo:** `standard-tooling`
> **Branch:** create from `develop`
> **Prereq:** none

Phase 1 is combined with the publish-and-docs rationalization (#318).
Both specs' standard-tooling work ships in a single release. Tasks 1-3
are from this spec (registry + `st-validate`). Tasks 4-5 wire existing
code to use the new registry. Task 6 covers the `st-version` dependency
from #318. Task 7 is the combined release.

### Task 1: Fix command registry and add install commands

**Files:**
- Modify: `src/standard_tooling/lib/validate_commands.py`
- Modify: `tests/standard_tooling/test_validate_commands.py`

Update the registry to match the spec: Python lint/typecheck target
`src/ tests/`, test coverage scoped to `src`, pip-audit plain
invocation. Add `CheckKind.INSTALL` and install commands per language.

- [ ] **Step 1: Write failing tests for updated Python commands**

Add/update in `tests/standard_tooling/test_validate_commands.py`:

```python
# -- Install commands ---------------------------------------------------------


def test_python_install_commands() -> None:
    cmds = language_commands("python", CheckKind.INSTALL)
    assert cmds == ["uv sync --frozen --group dev"]


def test_go_install_commands() -> None:
    cmds = language_commands("go", CheckKind.INSTALL)
    assert cmds == ["go mod download"]


def test_ruby_install_commands() -> None:
    cmds = language_commands("ruby", CheckKind.INSTALL)
    assert cmds == ["bundle install --jobs 4"]


def test_rust_install_commands() -> None:
    cmds = language_commands("rust", CheckKind.INSTALL)
    assert cmds == ["cargo fetch"]


def test_java_install_commands() -> None:
    cmds = language_commands("java", CheckKind.INSTALL)
    assert cmds == ["./mvnw dependency:resolve -B"]


def test_shell_install_commands() -> None:
    cmds = language_commands("shell", CheckKind.INSTALL)
    assert cmds == []
```

Update existing Python tests to match new commands:

```python
def test_python_lint_commands() -> None:
    cmds = language_commands("python", CheckKind.LINT)
    assert cmds == ["ruff check src/ tests/", "ruff format --check src/ tests/"]


def test_python_typecheck_commands() -> None:
    cmds = language_commands("python", CheckKind.TYPECHECK)
    assert "mypy src/ tests/" in cmds
    assert "ty check src tests" in cmds


def test_python_test_commands() -> None:
    cmds = language_commands("python", CheckKind.TEST)
    assert any("pytest" in c for c in cmds)
    assert any("--cov=src" in c for c in cmds)


def test_python_audit_commands() -> None:
    cmds = language_commands("python", CheckKind.AUDIT)
    assert any("uv sync --check" in c for c in cmds)
    assert any("uv lock --check" in c for c in cmds)
    assert "pip-audit" in cmds
    assert any("pip-licenses" in c for c in cmds)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_validate_commands.py -v`
Expected: FAIL — `CheckKind.INSTALL` does not exist, Python commands
differ from expected values.

- [ ] **Step 3: Update registry with fixed commands and install entries**

In `src/standard_tooling/lib/validate_commands.py`:

Add `INSTALL = "install"` to the `CheckKind` enum.

Update the `_REGISTRY` dict:

```python
_REGISTRY: dict[str, dict[CheckKind, list[str]]] = {
    "python": {
        CheckKind.INSTALL: ["uv sync --frozen --group dev"],
        CheckKind.LINT: ["ruff check src/ tests/", "ruff format --check src/ tests/"],
        CheckKind.TYPECHECK: ["mypy src/ tests/", "ty check src tests"],
        CheckKind.TEST: ["pytest --cov=src --cov-branch --cov-fail-under=100"],
        CheckKind.AUDIT: [
            "uv sync --check --frozen --group dev",
            "uv lock --check",
            "pip-audit",
            "pip-licenses --allow-only=<standard-allowlist>",
        ],
    },
    "go": {
        CheckKind.INSTALL: ["go mod download"],
        CheckKind.LINT: ["golangci-lint run ./...", "gocyclo -over 15 ."],
        CheckKind.TYPECHECK: ["go vet ./..."],
        CheckKind.TEST: [
            "go test -race -count=1 -coverprofile=coverage.out ./...",
            "go-test-coverage --config .testcoverage.yml",
        ],
        CheckKind.AUDIT: ["govulncheck ./...", "go-licenses check ./..."],
    },
    "java": {
        CheckKind.INSTALL: ["./mvnw dependency:resolve -B"],
        CheckKind.LINT: ["./mvnw spotless:check checkstyle:check -B"],
        CheckKind.TYPECHECK: ["./mvnw compile -B"],
        CheckKind.TEST: ["./mvnw verify -B"],
        CheckKind.AUDIT: [
            "./mvnw dependency:tree -B -q",
            "./mvnw org.codehaus.mojo:license-maven-plugin:add-third-party -B",
        ],
    },
    "ruby": {
        CheckKind.INSTALL: ["bundle install --jobs 4"],
        CheckKind.LINT: ["bundle exec rubocop"],
        CheckKind.TYPECHECK: ["bundle exec steep check"],
        CheckKind.TEST: ["bundle exec rake"],
        CheckKind.AUDIT: ["bundle exec bundle-audit check --update"],
    },
    "rust": {
        CheckKind.INSTALL: ["cargo fetch"],
        CheckKind.LINT: ["cargo fmt --all -- --check", "cargo clippy -- -D warnings"],
        CheckKind.TYPECHECK: ["cargo check"],
        CheckKind.TEST: ["cargo llvm-cov --fail-under-lines 100"],
        CheckKind.AUDIT: ["cargo deny check"],
    },
}
```

Note: `<standard-allowlist>` for pip-licenses needs the actual allowlist
value resolved during implementation. Check existing consumer repos for
the canonical allowlist string.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_validate_commands.py -v`
Expected: all PASS

- [ ] **Step 5: Commit**

```
st-commit --type feat --scope validate --message "fix Python commands and add install entries to command registry" --agent claude
```

### Task 2: Build `st-validate` command

**Files:**
- Create: `src/standard_tooling/bin/st_validate.py`
- Create: `tests/standard_tooling/test_st_validate.py`
- Modify: `pyproject.toml` (add entry point)

The unified validation command. Reads language from config, dispatches
to common checks or registry commands based on `--check` argument.

- [ ] **Step 1: Write failing tests for st-validate**

Create `tests/standard_tooling/test_st_validate.py`:

```python
"""Tests for standard_tooling.bin.st_validate."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import TYPE_CHECKING
from unittest.mock import MagicMock, patch

import pytest

from standard_tooling.bin.st_validate import main

if TYPE_CHECKING:
    pass


@pytest.fixture(autouse=True)
def _container_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ST_IN_DEV_CONTAINER", "1")


def _write_config(tmp_path: Path, language: str) -> None:
    (tmp_path / "standard-tooling.toml").write_text(
        f'[project]\nrepository-type = "library"\nversioning-scheme = "semver"\n'
        f'branching-model = "library-release"\nrelease-model = "tagged-release"\n'
        f'primary-language = "{language}"\n\n[dependencies]\nstandard-tooling = "v1.4"\n'
    )


# -- Container guard ----------------------------------------------------------


def test_rejects_host_execution(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ST_IN_DEV_CONTAINER", raising=False)
    with patch("standard_tooling.bin.st_validate._in_dev_container", return_value=False):
        assert main([]) == 1


# -- --check common -----------------------------------------------------------


def test_check_common_runs_common_checks(tmp_path: Path) -> None:
    _write_config(tmp_path, "python")
    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_common_checks", return_value=0) as mock,
    ):
        result = main(["--check", "common"])
    assert result == 0
    mock.assert_called_once()


# -- --check lint (language-specific) -----------------------------------------


def test_check_lint_runs_install_then_lint(tmp_path: Path) -> None:
    _write_config(tmp_path, "python")
    calls: list[str] = []

    def mock_run_commands(cmds: list[str], label: str) -> int:
        calls.extend(cmds)
        return 0

    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_commands", side_effect=mock_run_commands),
    ):
        result = main(["--check", "lint"])
    assert result == 0
    assert "uv sync --frozen --group dev" in calls
    assert "ruff check src/ tests/" in calls


def test_check_lint_no_commands_for_shell(tmp_path: Path) -> None:
    _write_config(tmp_path, "shell")
    with patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path):
        result = main(["--check", "lint"])
    assert result == 0


# -- No --check (run all) ----------------------------------------------------


def test_run_all_calls_common_then_language_checks(tmp_path: Path) -> None:
    _write_config(tmp_path, "python")
    order: list[str] = []

    def mock_common(repo_root: Path) -> int:
        order.append("common")
        return 0

    def mock_commands(cmds: list[str], label: str) -> int:
        order.append(label)
        return 0

    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_common_checks", side_effect=mock_common),
        patch("standard_tooling.bin.st_validate._run_commands", side_effect=mock_commands),
        patch("standard_tooling.bin.st_validate._find_custom_validator", return_value=None),
    ):
        result = main([])
    assert result == 0
    assert order[0] == "common"
    assert "install" in order
    assert "lint" in order
    assert "typecheck" in order
    assert "test" in order
    assert "audit" in order


def test_run_all_stops_on_failure(tmp_path: Path) -> None:
    _write_config(tmp_path, "python")

    def mock_common(repo_root: Path) -> int:
        return 1

    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_common_checks", side_effect=mock_common),
    ):
        result = main([])
    assert result == 1


def test_run_all_includes_custom_validator(tmp_path: Path) -> None:
    _write_config(tmp_path, "python")

    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_common_checks", return_value=0),
        patch("standard_tooling.bin.st_validate._run_commands", return_value=0),
        patch(
            "standard_tooling.bin.st_validate._find_custom_validator",
            return_value="/path/to/custom",
        ),
        patch(
            "standard_tooling.bin.st_validate._run_custom_validator",
            return_value=0,
        ) as mock_custom,
    ):
        result = main([])
    assert result == 0
    mock_custom.assert_called_once()


def test_run_all_language_none_skips_language_checks(tmp_path: Path) -> None:
    _write_config(tmp_path, "none")

    with (
        patch("standard_tooling.bin.st_validate.git.repo_root", return_value=tmp_path),
        patch("standard_tooling.bin.st_validate._run_common_checks", return_value=0),
        patch("standard_tooling.bin.st_validate._find_custom_validator", return_value=None),
    ):
        result = main([])
    assert result == 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_st_validate.py -v`
Expected: FAIL — module `standard_tooling.bin.st_validate` does not
exist.

- [ ] **Step 3: Implement `st-validate` command**

Create `src/standard_tooling/bin/st_validate.py`:

```python
"""Unified validation command.

Reads primary_language from standard-tooling.toml, then either runs a
specific check type (--check) or all checks in sequence:
  common → install → lint → typecheck → test → audit → custom
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from standard_tooling.lib import config, git
from standard_tooling.lib.validate_commands import CheckKind, language_commands

_CHECK_KINDS = {
    "common": None,
    "lint": CheckKind.LINT,
    "typecheck": CheckKind.TYPECHECK,
    "test": CheckKind.TEST,
    "audit": CheckKind.AUDIT,
}

_LANGUAGE_CHECK_ORDER = [
    CheckKind.LINT,
    CheckKind.TYPECHECK,
    CheckKind.TEST,
    CheckKind.AUDIT,
]


def _in_dev_container() -> bool:
    return Path("/.dockerenv").exists() or bool(os.environ.get("ST_IN_DEV_CONTAINER"))


def _run_commands(cmds: list[str], label: str) -> int:
    for cmd in cmds:
        print(f"Running ({label}): {cmd}")
        result = subprocess.run(  # noqa: S603
            cmd, shell=True, check=False,
        )
        if result.returncode != 0:
            return result.returncode
    return 0


def _run_common_checks(repo_root: Path) -> int:
    # Import here to avoid circular dependency and keep common checks
    # self-contained in their existing module.
    from standard_tooling.bin.validate_local_common_container import main as common_main
    return common_main()


def _find_custom_validator(repo_root: Path) -> str | None:
    scripts_bin = repo_root / "scripts" / "bin"
    entry_point = shutil.which("st-validate-local-custom")
    if entry_point is not None:
        return entry_point
    local = scripts_bin / "validate-local-custom"
    if local.is_file() and os.access(local, os.X_OK):
        return str(local)
    return None


def _run_custom_validator(path: str) -> int:
    print(f"Running: {path}")
    result = subprocess.run((path,), check=False)  # noqa: S603
    return result.returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="st-validate",
        description="Run validation checks from the command registry.",
    )
    parser.add_argument(
        "--check",
        choices=list(_CHECK_KINDS.keys()),
        default=None,
        help="Run only this check type. Omit to run all.",
    )
    args = parser.parse_args(argv)

    if not _in_dev_container():
        print(
            "ERROR: st-validate must run inside a dev container.\n"
            "       Run: st-docker-run -- st-validate",
            file=sys.stderr,
        )
        return 1

    repo_root = git.repo_root()

    try:
        st_config = config.read_config(repo_root)
        language = st_config.project.primary_language
    except FileNotFoundError:
        language = ""
    except config.ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.check is not None:
        return _run_single_check(args.check, language, repo_root)
    return _run_all_checks(language, repo_root)


def _run_single_check(check: str, language: str, repo_root: Path) -> int:
    if check == "common":
        return _run_common_checks(repo_root)

    kind = _CHECK_KINDS[check]
    cmds = language_commands(language, kind)
    if not cmds:
        print(f"No {check} commands for language '{language}'")
        return 0

    install_cmds = language_commands(language, CheckKind.INSTALL)
    if install_cmds:
        rc = _run_commands(install_cmds, "install")
        if rc != 0:
            return rc

    return _run_commands(cmds, check)


def _run_all_checks(language: str, repo_root: Path) -> int:
    print("=" * 40)
    print("st-validate")
    print(f"primary_language: {language or '<not set>'}")
    print("=" * 40)
    print()

    rc = _run_common_checks(repo_root)
    if rc != 0:
        return rc

    if language and language != "none":
        install_cmds = language_commands(language, CheckKind.INSTALL)
        if install_cmds:
            print()
            rc = _run_commands(install_cmds, "install")
            if rc != 0:
                return rc

        for kind in _LANGUAGE_CHECK_ORDER:
            cmds = language_commands(language, kind)
            if cmds:
                print()
                rc = _run_commands(cmds, kind.value)
                if rc != 0:
                    return rc

    custom = _find_custom_validator(repo_root)
    if custom is not None:
        print()
        rc = _run_custom_validator(custom)
        if rc != 0:
            return rc

    print()
    print("=" * 40)
    print("st-validate: all checks passed")
    print("=" * 40)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Add entry point to pyproject.toml**

Add to `[project.scripts]`:

```
st-validate = "standard_tooling.bin.st_validate:main"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_st_validate.py -v`
Expected: all PASS

Run full suite to verify no regressions:
`cd /Users/pmoore/dev/github/standard-tooling && uv run pytest -v`

- [ ] **Step 6: Commit**

```
st-commit --type feat --scope validate --message "add st-validate command with registry-driven check dispatch" --agent claude
```

### Task 3: Add hadolint and actionlint to common checks

**Files:**
- Modify: `src/standard_tooling/bin/validate_local_common_container.py`
- Modify: `tests/standard_tooling/test_validate_local_common_container.py`

The pushback review identified that ci-quality.yml currently runs
hadolint and actionlint in the common job, but
`validate_local_common_container.py` does not. Add them to close
the parity gap.

- [ ] **Step 1: Write failing tests for hadolint and actionlint**

Add to `tests/standard_tooling/test_validate_local_common_container.py`
tests that verify hadolint runs when `Dockerfile*` files exist and
actionlint runs when `.github/workflows/` exists.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Add hadolint and actionlint to common container checks**

In `src/standard_tooling/bin/validate_local_common_container.py`, add
after the yamllint block:

```python
    dockerfile_files = _find_dockerfiles(repo_root)
    if dockerfile_files:
        print(f"Running: hadolint ({len(dockerfile_files)} files)")
        result = subprocess.run(
            ["hadolint", *dockerfile_files],
            check=False,
        )
        if result.returncode != 0:
            return result.returncode

    workflows_dir = repo_root / ".github" / "workflows"
    if workflows_dir.is_dir():
        print("Running: actionlint")
        result = subprocess.run(
            ["actionlint"],
            check=False,
        )
        if result.returncode != 0:
            return result.returncode
```

Add the file-discovery helper:

```python
def _find_dockerfiles(repo_root: Path) -> list[str]:
    found: list[str] = []
    for path in repo_root.iterdir():
        if path.is_file() and path.name.startswith("Dockerfile"):
            found.append(str(path))
    return sorted(found)
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```
st-commit --type feat --scope validate --message "add hadolint and actionlint to common validation checks" --agent claude
```

### Task 4: Wire docker_cache.py to use registry install commands

**Files:**
- Modify: `src/standard_tooling/lib/docker_cache.py`
- Modify: `tests/standard_tooling/test_docker_cache.py`

Replace the `_WARMUP_COMMANDS` dict with a lookup against the command
registry.

- [ ] **Step 1: Write a test that verifies registry-driven warmup**

Add a test to `tests/standard_tooling/test_docker_cache.py` that
asserts the warmup command for Python comes from the registry (i.e.,
`uv sync --frozen --group dev`) rather than the old hardcoded value
(`uv sync --group dev`).

- [ ] **Step 2: Replace `_WARMUP_COMMANDS` with registry lookup**

In `src/standard_tooling/lib/docker_cache.py`, remove the
`_WARMUP_COMMANDS` dict and replace its usage with:

```python
from standard_tooling.lib.validate_commands import CheckKind, language_commands

def _warmup_command(lang: str) -> str:
    cmds = language_commands(lang, CheckKind.INSTALL)
    return " && ".join(cmds) if cmds else ""
```

Update `_build_cached_image` to call `_warmup_command(lang)` instead
of `_WARMUP_COMMANDS.get(lang)`.

- [ ] **Step 3: Run tests to verify no regressions**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_docker_cache.py -v`

- [ ] **Step 4: Commit**

```
st-commit --type refactor --scope docker --message "replace _WARMUP_COMMANDS with registry-driven install lookup" --agent claude
```

### Task 5: Update st-finalize-repo to call st-validate

**Files:**
- Modify: `src/standard_tooling/bin/finalize_repo.py`
- Modify: `tests/standard_tooling/test_finalize_repo.py`

Update the post-finalization validation call to use `st-validate`
instead of `st-validate-local`.

- [ ] **Step 1: Update the command in finalize_repo.py**

In `src/standard_tooling/bin/finalize_repo.py`, change lines 242-244:

From:
```python
            cmd: tuple[str, ...] = ("st-docker-run", "--", "uv", "run", "st-validate-local")
        else:
            cmd = ("st-docker-run", "--", "st-validate-local")
```

To:
```python
            cmd: tuple[str, ...] = ("st-docker-run", "--", "uv", "run", "st-validate")
        else:
            cmd = ("st-docker-run", "--", "st-validate")
```

Also update the dry-run message on line 250.

- [ ] **Step 2: Update tests**

Update `tests/standard_tooling/test_finalize_repo.py` to assert the
new command strings.

- [ ] **Step 3: Run tests to verify**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_finalize_repo.py -v`

- [ ] **Step 4: Commit**

```
st-commit --type refactor --scope finalize --message "call st-validate instead of st-validate-local in post-finalization" --agent claude
```

### Task 6: Build `st-version` library and CLI (from #318)

ci-release.yml (Task 11) depends on `st-version show` to extract
version strings for the version-divergence comparison. This task
implements `st-version` as defined in the publish-and-docs
rationalization plan.

ci-release.yml also requires `st-version show --ref <ref>` to read the
version from a git ref (e.g., `origin/main`) without checking out that
branch. The `--ref` argument reads the version file via
`git show <ref>:<path>` instead of the filesystem. This must be included
in the `st-version` implementation (see #318 plan Tasks 2-3).

**Full task details:** See
`docs/plans/2026-05-05-publish-and-docs-rationalization.md`, Tasks 2-3.
Those tasks define the complete `st-version` library (per-language
version discovery, show, show --major-minor, bump) and the CLI entry
point. Do not duplicate the steps here — execute Tasks 2-3 from that
plan, ensuring `--ref` support is included.

**Files (from #318 plan):**
- Create: `src/standard_tooling/lib/version.py`
- Create: `src/standard_tooling/bin/version.py`
- Create: `tests/standard_tooling/test_version.py`
- Create: `tests/standard_tooling/test_version_cli.py`
- Modify: `pyproject.toml` (add `st-version` entry point)

- [ ] **Step 1: Execute #318 Task 2 (st-version library)**
- [ ] **Step 2: Execute #318 Task 3 (st-version bump + CLI)**
- [ ] **Step 3: Verify st-version show works**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run st-version show`
Expected: outputs the current version from `VERSION` or `pyproject.toml`

- [ ] **Step 4: Verify st-version show --ref works**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run st-version show --ref HEAD`
Expected: outputs the same version (reading via `git show` instead of filesystem)

### Task 7: Full validation and release

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest -v --cov --cov-branch --cov-fail-under=100`

- [ ] **Step 2: Run local validation**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- uv run st-validate-local`

- [ ] **Step 3: Verify all Phase 1 deliverables**

Confirm these are all present and tested:
- `st-validate` command (Tasks 1-3)
- Registry with install commands and fixed Python entries (Task 1)
- docker_cache.py using registry (Task 4)
- finalize-repo using st-validate (Task 5)
- `st-version` command (Task 6)

- [ ] **Step 4: Release standard-tooling**

Tag and release the combined standard-tooling version containing
`st-validate`, registry fixes, and `st-version`.

---

## Phase 2: standard-actions workflows

> **Repo:** `standard-actions`
> **Branch:** `feature/337-ci-workflow-reset` (worktree:
> `.worktrees/issue-337-ci-workflow-reset/`)
> **Prereq:** Phase 1 complete (standard-tooling released with
> `st-validate` and `st-version`)

### Task 8: Implement ci-quality.yml

**Files:**
- Modify: `.github/workflows/ci-quality.yml`

Replace the stub lint and typecheck jobs with real implementations.
Keep the common job but replace inline tool invocations with
`st-validate --check common`.

- [ ] **Step 1: Rewrite ci-quality.yml**

```yaml
name: CI Quality

on:
  workflow_call:
    inputs:
      language:
        type: string
        required: true
      versions:
        type: string
        required: true

jobs:
  common:
    name: common
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-base:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Run common quality checks
        run: st-validate --check common

  lint:
    name: lint / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}:${{ matrix.version }}
    strategy:
      matrix:
        version: ${{ fromJSON(inputs.versions) }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Run lint
        run: st-validate --check lint

  typecheck:
    name: typecheck / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}:${{ matrix.version }}
    strategy:
      matrix:
        version: ${{ fromJSON(inputs.versions) }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Run typecheck
        run: st-validate --check typecheck
```

- [ ] **Step 2: Validate actionlint passes**

Run: `actionlint .github/workflows/ci-quality.yml`

- [ ] **Step 3: Commit**

```
st-commit --type feat --scope ci --message "implement ci-quality.yml with st-validate dispatch" --agent claude
```

### Task 9: Implement ci-test.yml

**Files:**
- Modify: `.github/workflows/ci-test.yml`

Replace stub unit job. Remove integration-tests input (per pushback
review: integration tests are repo-local).

- [ ] **Step 1: Rewrite ci-test.yml**

```yaml
name: CI Test

on:
  workflow_call:
    inputs:
      language:
        type: string
        required: true
      versions:
        type: string
        required: true

jobs:
  unit:
    name: unit / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}:${{ matrix.version }}
    strategy:
      matrix:
        version: ${{ fromJSON(inputs.versions) }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Run unit tests
        run: st-validate --check test
```

- [ ] **Step 2: Validate actionlint passes**

- [ ] **Step 3: Commit**

```
st-commit --type feat --scope ci --message "implement ci-test.yml with st-validate dispatch" --agent claude
```

### Task 10: Implement ci-audit.yml

**Files:**
- Modify: `.github/workflows/ci-audit.yml`

Replace stub dependencies job.

- [ ] **Step 1: Rewrite ci-audit.yml**

```yaml
name: CI Audit

on:
  workflow_call:
    inputs:
      language:
        type: string
        required: true
      versions:
        type: string
        required: true

jobs:
  dependencies:
    name: dependencies / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}:${{ matrix.version }}
    strategy:
      matrix:
        version: ${{ fromJSON(inputs.versions) }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Run dependency audit
        run: st-validate --check audit
```

- [ ] **Step 2: Validate actionlint passes**

- [ ] **Step 3: Commit**

```
st-commit --type feat --scope ci --message "implement ci-audit.yml with st-validate dispatch" --agent claude
```

### Task 11: Implement ci-release.yml

**Files:**
- Modify: `.github/workflows/ci-release.yml`

Replace stub version-bump job with the version-divergence action
using `st-version show`.

- [ ] **Step 1: Rewrite ci-release.yml**

```yaml
name: CI Release

on:
  workflow_call:
    inputs:
      language:
        type: string
        required: true
      run-release:
        type: boolean
        default: true

jobs:
  version-bump:
    name: version-bump
    if: ${{ inputs.run-release }}
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-base:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Verify version bump
        uses: wphillipmoore/standard-actions/actions/release-gates/version-divergence@develop
        with:
          head-version-command: st-version show
          main-version-command: st-version show --ref origin/main
```

`st-version show` reads the version file from the filesystem (PR
branch). `st-version show --ref origin/main` reads the version file
via `git show origin/main:<path>`, avoiding any worktree or checkout
manipulation. The `--ref` argument is built in Task 6 (Phase 1).

- [ ] **Step 2: Validate actionlint passes**

- [ ] **Step 3: Commit**

```
st-commit --type feat --scope ci --message "implement ci-release.yml with st-version version-bump gate" --agent claude
```

### Task 12: Update ci.yml self-referencing orchestrator

**Files:**
- Modify: `.github/workflows/ci.yml`

Ensure the orchestrator correctly calls all reusable workflows for
standard-actions (a shell repo).

- [ ] **Step 1: Review and update ci.yml if needed**

The current ci.yml already calls ci-quality, ci-security, and
ci-release. Verify inputs match the updated workflow signatures
(e.g., `versions` is required for ci-quality). No ci-test or ci-audit
calls needed for a shell repo.

- [ ] **Step 2: Commit if changes were needed**

```
st-commit --type ci --message "update ci.yml orchestrator for updated workflow signatures" --agent claude
```

### Task 13: Validate and release

- [ ] **Step 1: Run local validation**

Run: `st-docker-run -- st-validate`

- [ ] **Step 2: Push branch and create PR**

Push `feature/337-ci-workflow-reset` and create PR targeting `develop`.
The self-referencing CI will test the updated workflows against the
standard-actions repo itself.

- [ ] **Step 3: Verify CI passes**

All checks should pass:
- `quality / common` — runs st-validate --check common (shellcheck,
  markdownlint, yamllint, actionlint, repo-profile)
- `quality / lint / latest` — runs st-validate --check lint (exits 0,
  no lint commands for shell)
- `quality / typecheck / latest` — runs st-validate --check typecheck
  (exits 0, no typecheck commands for shell)
- `security / *` — unchanged, already working
- `release / version-bump` — runs version-divergence check

- [ ] **Step 4: Merge and tag v1.6**

---

## Phase 3: consumer re-sweep

> **Repos:** mq-rest-admin-python, ai-research-methodology, then all
> remaining managed repos
> **Prereq:** Phase 2 complete (standard-actions v1.6 released)

### Task 14: Update mq-rest-admin-python

- [ ] **Step 1: Replace bespoke CI with thin wrappers**

Rewrite `.github/workflows/ci.yml` to use reusable workflows from
`standard-actions@v1.6`. Remove all bespoke lint, typecheck, test,
audit jobs.

- [ ] **Step 2: Remove scripts/dev/ validation scripts**

Remove `scripts/dev/lint.sh`, `typecheck.sh`, `test.sh`, `audit.sh`.
Keep `scripts/dev/test-integration.sh` if it exists (integration tests
are repo-local). Keep any `validate_*` scripts that are tracked by
centralization issues (#526-#532).

- [ ] **Step 3: Verify CI passes**

- [ ] **Step 4: Commit and merge**

### Task 15: Update ai-research-methodology

Same pattern as Task 14.

### Task 16: Update remaining repos

Repeat for each remaining managed repo: standard-tooling,
mq-rest-admin-go, mq-rest-admin-java, mq-rest-admin-ruby,
mq-rest-admin-rust, standard-tooling-docker, standard-tooling-plugin.
