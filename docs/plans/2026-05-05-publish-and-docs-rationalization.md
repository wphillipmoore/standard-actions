# Publish and Docs Rationalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert publish and docs workflows to zero-input reusable
workflows in standard-actions, with all per-repo config derived from
`standard-tooling.toml`.

**Architecture:** Three sequential phases — (1) build `st-version` CLI
and extend `standard-tooling.toml` schema in standard-tooling, (2)
create/refactor reusable workflows and composite actions in
standard-actions, (3) roll out thin callers across the fleet. Each phase
produces a releasable artifact before the next begins.

**Tech Stack:** Python 3.12+ (standard-tooling CLI), GitHub Actions YAML
(reusable workflows), TOML (configuration), shell (composite actions)

**Spec:** `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`

---

## Phase 1: standard-tooling foundations

> **Repo:** `standard-tooling`
> **Branch:** create from `develop`
> **Prereq:** none

Phase 1 may be split across multiple PRs. Tasks 1-3 form a natural PR
(`st-version` + config schema). Task 4 is an independent PR
(`st-github-config` extension). Task 5 is the release.

### Task 1: Extend config schema with `[publish]` section

**Files:**
- Modify: `src/standard_tooling/lib/config.py`
- Modify: `tests/standard_tooling/test_config.py`

The `[publish]` section is optional in `standard-tooling.toml`. When
present, it declares which post-merge workflows a repo uses. When
absent, defaults apply (`docs = true`, `release = false`).

- [ ] **Step 1: Write failing tests for publish config parsing**

Add to `tests/standard_tooling/test_config.py`:

```python
# -- [publish] section --------------------------------------------------------

_PUBLISH_TOML = """\
[project]
repository-type = "library"
versioning-scheme = "semver"
branching-model = "library-release"
release-model = "tagged-release"
primary-language = "python"

[dependencies]
standard-tooling = "v1.4"

[publish]
release = true
docs = true
"""


def test_publish_section_parsed(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_PUBLISH_TOML)
    cfg = read_config(tmp_path)
    assert cfg.publish is not None
    assert cfg.publish.release is True
    assert cfg.publish.docs is True


def test_publish_section_defaults_when_absent(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_INSTALL_TAG_TOML)
    cfg = read_config(tmp_path)
    assert cfg.publish is not None
    assert cfg.publish.release is False
    assert cfg.publish.docs is True


_PUBLISH_RELEASE_ONLY_TOML = """\
[project]
repository-type = "library"
versioning-scheme = "semver"
branching-model = "library-release"
release-model = "tagged-release"
primary-language = "python"

[dependencies]
standard-tooling = "v1.4"

[publish]
release = true
"""


def test_publish_docs_defaults_true(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_PUBLISH_RELEASE_ONLY_TOML)
    cfg = read_config(tmp_path)
    assert cfg.publish.docs is True
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_config.py -v -k publish`
Expected: FAIL — `StConfig` has no `publish` attribute

- [ ] **Step 3: Add PublishConfig dataclass and parsing**

In `src/standard_tooling/lib/config.py`, add after `GithubOverrides`:

```python
@dataclass
class PublishConfig:
    release: bool
    docs: bool
```

Update `StConfig`:

```python
@dataclass
class StConfig:
    project: ProjectConfig
    dependencies: dict[str, str]
    markdownlint: MarkdownlintConfig
    ci: CiConfig | None
    github: GithubOverrides
    publish: PublishConfig
```

In `_parse_raw_config`, add before the final `return`:

```python
    publish_raw = raw.get("publish", {})
    publish = PublishConfig(
        release=bool(publish_raw.get("release", False)),
        docs=bool(publish_raw.get("docs", True)),
    )
```

Add `publish=publish` to the `StConfig(...)` constructor call.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_config.py -v`
Expected: all PASS (existing tests must not break)

- [ ] **Step 5: Commit**

```
st-commit --type feat --scope config --message "add [publish] section to standard-tooling.toml schema" --agent claude
```

### Task 2: Create `st-version` library

**Files:**
- Create: `src/standard_tooling/lib/version.py`
- Create: `tests/standard_tooling/test_version.py`

This is the core library that discovers, reads, and bumps version
strings based on `primary-language` from `standard-tooling.toml`.

- [ ] **Step 1: Write failing tests for version discovery and show**

Create `tests/standard_tooling/test_version.py`:

```python
"""Tests for standard_tooling.lib.version."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from standard_tooling.lib.version import show, show_major_minor

if TYPE_CHECKING:
    from pathlib import Path


# -- Fixture helpers ----------------------------------------------------------

def _write_toml(tmp_path: Path, language: str) -> None:
    (tmp_path / "standard-tooling.toml").write_text(f"""\
[project]
repository-type = "library"
versioning-scheme = "semver"
branching-model = "library-release"
release-model = "tagged-release"
primary-language = "{language}"

[dependencies]
standard-tooling = "v1.4"
""")


# -- show() tests ------------------------------------------------------------

def test_show_python(tmp_path: Path) -> None:
    _write_toml(tmp_path, "python")
    (tmp_path / "pyproject.toml").write_text(
        '[project]\nname = "example"\nversion = "1.2.3"\n'
    )
    assert show(tmp_path) == "1.2.3"


def test_show_generic_version_file(tmp_path: Path) -> None:
    _write_toml(tmp_path, "shell")
    (tmp_path / "VERSION").write_text("2.0.1\n")
    assert show(tmp_path) == "2.0.1"


def test_show_rust(tmp_path: Path) -> None:
    _write_toml(tmp_path, "rust")
    (tmp_path / "Cargo.toml").write_text(
        '[package]\nname = "example"\nversion = "0.3.7"\n'
    )
    assert show(tmp_path) == "0.3.7"


def test_show_ruby(tmp_path: Path) -> None:
    _write_toml(tmp_path, "ruby")
    version_dir = tmp_path / "lib" / "mq" / "rest" / "admin"
    version_dir.mkdir(parents=True)
    (version_dir / "version.rb").write_text('  VERSION = \'4.1.0\'\n')
    assert show(tmp_path) == "4.1.0"


def test_show_go(tmp_path: Path) -> None:
    _write_toml(tmp_path, "go")
    pkg_dir = tmp_path / "mqrestadmin"
    pkg_dir.mkdir()
    (pkg_dir / "version.go").write_text('package mqrestadmin\n\nVersion = "1.0.5"\n')
    assert show(tmp_path) == "1.0.5"


def test_show_java(tmp_path: Path) -> None:
    _write_toml(tmp_path, "java")
    (tmp_path / "pom.xml").write_text(
        "<project>\n  <version>3.2.1</version>\n</project>\n"
    )
    assert show(tmp_path) == "3.2.1"


# -- show_major_minor() tests ------------------------------------------------

def test_show_major_minor(tmp_path: Path) -> None:
    _write_toml(tmp_path, "shell")
    (tmp_path / "VERSION").write_text("1.5.2\n")
    assert show_major_minor(tmp_path) == "1.5"


# -- version_file override ---------------------------------------------------

def test_show_with_version_file_override(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text("""\
[project]
repository-type = "library"
versioning-scheme = "semver"
branching-model = "library-release"
release-model = "tagged-release"
primary-language = "shell"
version-file = "custom/VERSION"

[dependencies]
standard-tooling = "v1.4"
""")
    custom_dir = tmp_path / "custom"
    custom_dir.mkdir()
    (custom_dir / "VERSION").write_text("9.8.7\n")
    assert show(tmp_path) == "9.8.7"


# -- error cases --------------------------------------------------------------

def test_show_missing_version_file(tmp_path: Path) -> None:
    _write_toml(tmp_path, "shell")
    with pytest.raises(FileNotFoundError):
        show(tmp_path)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_version.py -v`
Expected: FAIL — module `standard_tooling.lib.version` does not exist

- [ ] **Step 3: Implement version show logic**

Create `src/standard_tooling/lib/version.py`:

```python
"""Version management for standard-tooling managed repositories.

Discovers, reads, and bumps version strings based on the
``primary-language`` field in ``standard-tooling.toml``.
"""

from __future__ import annotations

import re
import tomllib
from pathlib import Path

from standard_tooling.lib.config import read_config

_RUBY_VERSION_RE = re.compile(r"VERSION\s*=\s*'([^']+)'")
_GO_VERSION_RE = re.compile(r'Version\s*=\s*"([^"]+)"')
_JAVA_VERSION_RE = re.compile(r"<version>([^<]+)</version>")


def _discover_version_file(repo_root: Path, language: str) -> Path:
    """Find the version file using language conventions."""
    defaults: dict[str, str | None] = {
        "python": "pyproject.toml",
        "rust": "Cargo.toml",
        "java": "pom.xml",
        "shell": "VERSION",
        "none": "VERSION",
    }
    if language in defaults:
        return repo_root / defaults[language]

    if language == "ruby":
        matches = list(repo_root.glob("lib/**/version.rb"))
        if not matches:
            msg = f"No lib/**/version.rb found in {repo_root}"
            raise FileNotFoundError(msg)
        return matches[0]

    if language == "go":
        matches = list(repo_root.glob("**/version.go"))
        matches = [m for m in matches if ".git" not in m.parts]
        if not matches:
            msg = f"No **/version.go found in {repo_root}"
            raise FileNotFoundError(msg)
        return matches[0]

    msg = f"Unsupported language for version discovery: {language}"
    raise ValueError(msg)


def _read_version(version_file: Path, language: str) -> str:
    """Extract the version string from a version file."""
    text = version_file.read_text()

    if language == "python":
        data = tomllib.loads(text)
        return str(data["project"]["version"])

    if language == "rust":
        data = tomllib.loads(text)
        return str(data["package"]["version"])

    if language == "ruby":
        m = _RUBY_VERSION_RE.search(text)
        if not m:
            msg = f"No VERSION = '...' found in {version_file}"
            raise ValueError(msg)
        return m.group(1)

    if language == "go":
        m = _GO_VERSION_RE.search(text)
        if not m:
            msg = f"No Version = \"...\" found in {version_file}"
            raise ValueError(msg)
        return m.group(1)

    if language == "java":
        m = _JAVA_VERSION_RE.search(text)
        if not m:
            msg = f"No <version>...</version> found in {version_file}"
            raise ValueError(msg)
        return m.group(1)

    # generic: VERSION file
    return text.strip()


def _get_version_file(repo_root: Path) -> tuple[Path, str]:
    """Return (version_file_path, language) for a repo."""
    cfg = read_config(repo_root)
    language = cfg.project.primary_language

    # Check for explicit override
    raw_toml = (repo_root / "standard-tooling.toml").read_text()
    raw = tomllib.loads(raw_toml)
    override = raw.get("project", {}).get("version-file")
    if override:
        return repo_root / override, language

    version_file = _discover_version_file(repo_root, language)
    if not version_file.is_file():
        msg = f"Version file not found: {version_file}"
        raise FileNotFoundError(msg)
    return version_file, language


def show(repo_root: Path) -> str:
    """Return the current version string for a repo."""
    version_file, language = _get_version_file(repo_root)
    return _read_version(version_file, language)


def show_major_minor(repo_root: Path) -> str:
    """Return major.minor from the current version."""
    version = show(repo_root)
    parts = version.split(".")
    return f"{parts[0]}.{parts[1]}"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_version.py -v`
Expected: all PASS

- [ ] **Step 5: Commit**

```
st-commit --type feat --scope version --message "add st-version show library with per-language version discovery" --agent claude
```

### Task 3: Add `st-version bump` and CLI entry point

**Files:**
- Modify: `src/standard_tooling/lib/version.py`
- Create: `src/standard_tooling/bin/version.py`
- Modify: `pyproject.toml`
- Modify: `tests/standard_tooling/test_version.py`
- Create: `tests/standard_tooling/test_version_cli.py`

- [ ] **Step 1: Write failing tests for bump**

Add to `tests/standard_tooling/test_version.py`:

```python
from standard_tooling.lib.version import bump


# -- bump() tests ------------------------------------------------------------

def test_bump_generic(tmp_path: Path) -> None:
    _write_toml(tmp_path, "shell")
    (tmp_path / "VERSION").write_text("1.2.3\n")
    result = bump(tmp_path)
    assert result == "1.2.4"
    assert (tmp_path / "VERSION").read_text().strip() == "1.2.4"


def test_bump_python(tmp_path: Path) -> None:
    _write_toml(tmp_path, "python")
    (tmp_path / "pyproject.toml").write_text(
        '[project]\nname = "example"\nversion = "2.0.0"\n'
    )
    result = bump(tmp_path)
    assert result == "2.0.1"
    text = (tmp_path / "pyproject.toml").read_text()
    assert 'version = "2.0.1"' in text


def test_bump_rust(tmp_path: Path) -> None:
    _write_toml(tmp_path, "rust")
    (tmp_path / "Cargo.toml").write_text(
        '[package]\nname = "example"\nversion = "0.3.7"\n'
    )
    result = bump(tmp_path)
    assert result == "0.3.8"
    text = (tmp_path / "Cargo.toml").read_text()
    assert 'version = "0.3.8"' in text


def test_bump_ruby(tmp_path: Path) -> None:
    _write_toml(tmp_path, "ruby")
    version_dir = tmp_path / "lib" / "mq"
    version_dir.mkdir(parents=True)
    (version_dir / "version.rb").write_text("  VERSION = '1.0.0'\n")
    result = bump(tmp_path)
    assert result == "1.0.1"
    text = (version_dir / "version.rb").read_text()
    assert "VERSION = '1.0.1'" in text


def test_bump_go(tmp_path: Path) -> None:
    _write_toml(tmp_path, "go")
    pkg_dir = tmp_path / "pkg"
    pkg_dir.mkdir()
    (pkg_dir / "version.go").write_text('package pkg\n\nVersion = "1.0.5"\n')
    result = bump(tmp_path)
    assert result == "1.0.6"
    text = (pkg_dir / "version.go").read_text()
    assert 'Version = "1.0.6"' in text


def test_bump_java(tmp_path: Path) -> None:
    _write_toml(tmp_path, "java")
    (tmp_path / "pom.xml").write_text(
        "<project>\n  <version>3.2.1</version>\n</project>\n"
    )
    result = bump(tmp_path)
    assert result == "3.2.2"
    text = (tmp_path / "pom.xml").read_text()
    assert "<version>3.2.2</version>" in text


# -- lockfile maintenance tests -----------------------------------------------

from unittest.mock import patch


def test_bump_python_runs_uv_lock(tmp_path: Path) -> None:
    _write_toml(tmp_path, "python")
    (tmp_path / "pyproject.toml").write_text(
        '[project]\nname = "example"\nversion = "1.0.0"\n'
    )
    with patch("standard_tooling.lib.version.subprocess.run") as mock_run:
        bump(tmp_path)
        mock_run.assert_called_once_with(
            ["uv", "lock"], cwd=tmp_path, check=True,
        )


def test_bump_rust_runs_cargo_update(tmp_path: Path) -> None:
    _write_toml(tmp_path, "rust")
    (tmp_path / "Cargo.toml").write_text(
        '[package]\nname = "example"\nversion = "0.1.0"\n'
    )
    with patch("standard_tooling.lib.version.subprocess.run") as mock_run:
        bump(tmp_path)
        mock_run.assert_called_once_with(
            ["cargo", "update", "--workspace"], cwd=tmp_path, check=True,
        )


def test_bump_ruby_runs_bundle_install(tmp_path: Path) -> None:
    _write_toml(tmp_path, "ruby")
    version_dir = tmp_path / "lib" / "mq"
    version_dir.mkdir(parents=True)
    (version_dir / "version.rb").write_text("  VERSION = '1.0.0'\n")
    with patch("standard_tooling.lib.version.subprocess.run") as mock_run:
        bump(tmp_path)
        mock_run.assert_called_once_with(
            ["bundle", "install"], cwd=tmp_path, check=True,
        )


def test_bump_generic_skips_lockfile(tmp_path: Path) -> None:
    _write_toml(tmp_path, "shell")
    (tmp_path / "VERSION").write_text("1.0.0\n")
    with patch("standard_tooling.lib.version.subprocess.run") as mock_run:
        bump(tmp_path)
        mock_run.assert_not_called()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_version.py -v -k bump`
Expected: FAIL — `bump` not importable

- [ ] **Step 3: Implement bump logic**

Add to `src/standard_tooling/lib/version.py`:

```python
import subprocess

_LOCKFILE_COMMANDS: dict[str, list[str]] = {
    "python": ["uv", "lock"],
    "rust": ["cargo", "update", "--workspace"],
    "ruby": ["bundle", "install"],
}


def _increment_patch(version: str) -> str:
    """Increment the patch component of a semver string."""
    parts = version.split(".")
    parts[2] = str(int(parts[2]) + 1)
    return ".".join(parts)


def _write_version(version_file: Path, language: str, old: str, new: str) -> None:
    """Replace the version string in a version file."""
    text = version_file.read_text()

    if language in ("python", "rust"):
        text = text.replace(f'version = "{old}"', f'version = "{new}"', 1)
    elif language == "ruby":
        text = text.replace(f"VERSION = '{old}'", f"VERSION = '{new}'", 1)
    elif language == "go":
        text = text.replace(f'Version = "{old}"', f'Version = "{new}"', 1)
    elif language == "java":
        text = text.replace(f"<version>{old}</version>", f"<version>{new}</version>", 1)
    else:
        text = new + "\n"

    version_file.write_text(text)


def _run_lockfile_maintenance(repo_root: Path, language: str) -> None:
    """Run the appropriate lockfile command after a version bump."""
    cmd = _LOCKFILE_COMMANDS.get(language)
    if cmd is None:
        return
    subprocess.run(cmd, cwd=repo_root, check=True)


def bump(repo_root: Path) -> str:
    """Increment the patch version, update version file, and maintain lockfile."""
    version_file, language = _get_version_file(repo_root)
    old_version = _read_version(version_file, language)
    new_version = _increment_patch(old_version)
    _write_version(version_file, language, old_version, new_version)
    _run_lockfile_maintenance(repo_root, language)
    return new_version
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_version.py -v`
Expected: all PASS

- [ ] **Step 5: Create CLI entry point**

Create `src/standard_tooling/bin/version.py`:

```python
"""CLI entry point for st-version."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from standard_tooling.lib.version import bump, show, show_major_minor


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="st-version",
        description="Version management for standard-tooling repos",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    show_parser = sub.add_parser("show", help="Print current version")
    show_parser.add_argument(
        "--major-minor",
        action="store_true",
        help="Print major.minor only",
    )

    sub.add_parser("bump", help="Increment patch version")

    args = parser.parse_args()
    repo_root = Path.cwd()

    if args.command == "show":
        if args.major_minor:
            print(show_major_minor(repo_root))  # noqa: T201
        else:
            print(show(repo_root))  # noqa: T201
    elif args.command == "bump":
        new_version = bump(repo_root)
        print(new_version)  # noqa: T201


if __name__ == "__main__":
    main()
```

- [ ] **Step 6: Register in pyproject.toml**

Add to the `[project.scripts]` section:

```toml
st-version = "standard_tooling.bin.version:main"
```

- [ ] **Step 7: Write CLI tests**

Create `tests/standard_tooling/test_version_cli.py`:

```python
"""Tests for st-version CLI."""

from __future__ import annotations

import subprocess
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pathlib import Path


_TOML = """\
[project]
repository-type = "library"
versioning-scheme = "semver"
branching-model = "library-release"
release-model = "tagged-release"
primary-language = "shell"

[dependencies]
standard-tooling = "v1.4"
"""


def test_show(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_TOML)
    (tmp_path / "VERSION").write_text("1.2.3\n")
    result = subprocess.run(
        ["uv", "run", "st-version", "show"],
        capture_output=True, text=True, cwd=tmp_path, check=True,
    )
    assert result.stdout.strip() == "1.2.3"


def test_show_major_minor(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_TOML)
    (tmp_path / "VERSION").write_text("1.2.3\n")
    result = subprocess.run(
        ["uv", "run", "st-version", "show", "--major-minor"],
        capture_output=True, text=True, cwd=tmp_path, check=True,
    )
    assert result.stdout.strip() == "1.2"


def test_bump(tmp_path: Path) -> None:
    (tmp_path / "standard-tooling.toml").write_text(_TOML)
    (tmp_path / "VERSION").write_text("1.2.3\n")
    result = subprocess.run(
        ["uv", "run", "st-version", "bump"],
        capture_output=True, text=True, cwd=tmp_path, check=True,
    )
    assert result.stdout.strip() == "1.2.4"
    assert (tmp_path / "VERSION").read_text().strip() == "1.2.4"
```

- [ ] **Step 8: Run all tests**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_version.py tests/standard_tooling/test_version_cli.py -v`
Expected: all PASS

- [ ] **Step 9: Commit**

```
st-commit --type feat --scope version --message "add st-version bump and CLI entry point" --agent claude
```

### Task 4: Extend `st-github-config` for publish validation

**Files:**
- Modify: `src/standard_tooling/lib/github_config.py`
- Modify: `tests/standard_tooling/test_github_config_lib.py`

This adds awareness of post-merge workflow naming to the config engine.
These are NOT added to the CI gates ruleset — they are validated but not
enforced via rulesets.

- [ ] **Step 1: Write failing tests for publish config in desired state**

Add to `tests/standard_tooling/test_github_config_lib.py`:

```python
from standard_tooling.lib.config import PublishConfig


def _publish(*, release: bool = True, docs: bool = True) -> PublishConfig:
    return PublishConfig(release=release, docs=docs)


def test_compute_desired_state_includes_publish(
) -> None:
    config = StConfig(
        project=_project(),
        dependencies={"standard-tooling": "v1.4"},
        markdownlint=MarkdownlintConfig(ignore=[]),
        ci=_ci(),
        github=GithubOverrides(skip_rulesets=False),
        publish=_publish(),
    )
    state = compute_desired_state(config)
    assert state.publish is not None
    assert state.publish.release is True
    assert state.publish.docs is True


def test_compute_desired_state_publish_defaults() -> None:
    config = StConfig(
        project=_project(),
        dependencies={"standard-tooling": "v1.4"},
        markdownlint=MarkdownlintConfig(ignore=[]),
        ci=_ci(),
        github=GithubOverrides(skip_rulesets=False),
        publish=_publish(release=False),
    )
    state = compute_desired_state(config)
    assert state.publish.release is False
    assert state.publish.docs is True
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_github_config_lib.py -v -k publish`
Expected: FAIL — `DesiredState` has no `publish` attribute

- [ ] **Step 3: Add publish to DesiredState**

In `src/standard_tooling/lib/github_config.py`, add:

```python
@dataclass
class DesiredPublishConfig:
    release: bool
    docs: bool
```

Add `publish: DesiredPublishConfig` to `DesiredState`.

Update `compute_desired_state` to pass through:

```python
    publish = DesiredPublishConfig(
        release=config.publish.release,
        docs=config.publish.docs,
    )
    return DesiredState(
        ...
        publish=publish,
    )
```

Update `fetch_actual_state` to return a default `DesiredPublishConfig`
(publish state is not stored in GitHub API — it is file-based):

```python
    publish = DesiredPublishConfig(release=False, docs=False)
    # Publish config is validated from workflow files, not GitHub API
```

- [ ] **Step 4: Run all github_config tests**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest tests/standard_tooling/test_github_config_lib.py tests/standard_tooling/test_github_config_cli.py -v`
Expected: all PASS

- [ ] **Step 5: Commit**

```
st-commit --type feat --scope github-config --message "add [publish] section to desired state for naming validation" --agent claude
```

### Task 5: Update standard-tooling's own `standard-tooling.toml`

**Files:**
- Modify: `standard-tooling.toml`

- [ ] **Step 1: Add `[publish]` section**

Add to `standard-tooling.toml` (the `[publish]` section may already
exist with `consumer-refresh` — add the new fields alongside it):

```toml
[publish]
release = true
docs = true
```

- [ ] **Step 2: Run full test suite to verify no regressions**

Run: `cd /Users/pmoore/dev/github/standard-tooling && uv run pytest -v`
Expected: all PASS

- [ ] **Step 3: Commit**

```
st-commit --type chore --scope config --message "add publish.release and publish.docs to standard-tooling.toml" --agent claude
```

### Task 6: Release standard-tooling

- [ ] **Step 1: Use `st-prepare-release` to cut a release**

Follow the standard release workflow. The new version must be published
and the dev-base container rebuilt before Phase 2 can begin, since
standard-actions' reusable workflows run in the dev-base container
which bundles standard-tooling.

---

## Phase 2: standard-actions reusable workflows

> **Repo:** `standard-actions`
> **Worktree:** `.worktrees/issue-318-publish-docs-rationalization/`
> **Branch:** `feature/318-publish-docs-rationalization`
> **Prereq:** Phase 1 released, dev-base container rebuilt

All file paths in Phase 2 are relative to the worktree root:
`/Users/pmoore/dev/github/standard-actions/.worktrees/issue-318-publish-docs-rationalization/`

### Task 7: Create `publish-docs.yml` reusable workflow

**Files:**
- Create: `.github/workflows/publish-docs.yml`
- Delete: `.github/workflows/docs.yml`

The workflow uses dual triggers (`push` + `workflow_call`) so a
single file serves as both the reusable workflow for consuming repos
and the directly-triggered workflow for standard-actions itself.
This keeps the filename `publish-docs.yml` consistent everywhere.
Delete the old `docs.yml` in the same commit to avoid duplicate
triggers.

- [ ] **Step 1: Create the dual-trigger workflow and delete docs.yml**

```yaml
name: Publish docs

on:
  push:
    branches: [develop, main]
  workflow_dispatch:
  workflow_call:
    inputs:
      pre-deploy-command:
        description: Shell command to run before deploy.
        type: string
        default: ""
      mkdocs-config:
        description: Path to mkdocs.yml configuration file.
        type: string
        default: docs/site/mkdocs.yml

permissions:
  contents: write

concurrency:
  group: docs
  cancel-in-progress: false

jobs:
  deploy:
    name: "docs"
    runs-on: ubuntu-latest
    container: ghcr.io/wphillipmoore/dev-base:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Detect ecosystem
        id: ecosystem
        shell: bash
        run: |
          lang=$(python3 -c "
          import tomllib, pathlib
          cfg = tomllib.loads(pathlib.Path('standard-tooling.toml').read_text())
          print(cfg['project']['primary-language'])
          ")
          echo "language=$lang" >> "$GITHUB_OUTPUT"

      - name: Determine version
        id: version
        shell: bash
        run: |
          echo "major-minor=$(st-version show --major-minor)" >> "$GITHUB_OUTPUT"

      - name: Run pre-deploy command
        if: inputs.pre-deploy-command != ''
        shell: bash
        run: ${{ inputs.pre-deploy-command }}

      - name: Determine mike command
        id: mike
        shell: bash
        run: |
          if [ "${{ steps.ecosystem.outputs.language }}" = "python" ]; then
            echo "cmd=uv run mike" >> "$GITHUB_OUTPUT"
          else
            echo "cmd=mike" >> "$GITHUB_OUTPUT"
          fi

      - name: Deploy docs
        uses: wphillipmoore/standard-actions/actions/docs-deploy@develop
        with:
          version-command: echo ${{ steps.version.outputs.major-minor }}
          mkdocs-config: ${{ inputs.mkdocs-config }}
          mike-command: ${{ steps.mike.outputs.cmd }}
```

Delete `.github/workflows/docs.yml`.

- [ ] **Step 2: Commit**

```
st-commit --type feat --message "add publish-docs.yml dual-trigger reusable workflow, delete docs.yml" --agent claude
```

### Task 9: Refactor `tag-and-release` composite action

**Files:**
- Modify: `actions/publish/tag-and-release/action.yml`

Remove `release-title` and `release-notes` as required inputs. Derive
the title from `github.repository` + version. Derive the body as a
link to the GitHub Pages documentation site.

- [ ] **Step 1: Update action.yml**

Replace the `release-title` and `release-notes` inputs with optional
overrides (defaulting to derived values). Update the GitHub Release
creation step to use derived values:

```yaml
  release-title:
    description: >-
      Release title override. Defaults to "<repo-name> v<version>".
    required: false
    default: ""
  release-notes:
    description: >-
      Release notes override. Defaults to a link to the GitHub Pages
      documentation site.
    required: false
    default: ""
```

Update the "Create GitHub Release" step:

```bash
      # Derive defaults
      repo_name="${{ github.event.repository.name }}"
      owner="${{ github.repository_owner }}"
      default_title="${repo_name} ${{ steps.meta.outputs.tag }}"
      default_notes="Documentation: https://${owner}.github.io/${repo_name}/"

      title="${{ inputs.release-title }}"
      if [ -z "$title" ]; then
        title="$default_title"
      fi

      notes="${{ inputs.release-notes }}"
      if [ -z "$notes" ]; then
        notes="$default_notes"
      fi
```

- [ ] **Step 2: Verify standard-actions' own `publish.yml` still works**

Standard-actions' `publish.yml` currently passes `release-title` and
`release-notes` explicitly. Update it to stop passing these (use the
new defaults). Also update the job name to `"publish / release"`.

- [ ] **Step 3: Commit**

```
st-commit --type refactor --scope tag-and-release --message "auto-derive release title and notes from repo metadata" --agent claude
```

### Task 10: Clean up `docs-deploy` composite action

**Files:**
- Modify: `actions/docs-deploy/action.yml`

Remove the `checkout-common` and `checkout-common-ref` inputs and the
corresponding `actions/checkout` step for mq-rest-admin-common. This
domain-specific logic violates Design Goal #4.

- [ ] **Step 1: Remove checkout-common inputs and step**

Remove the `checkout-common` and `checkout-common-ref` input
declarations. Remove the "Checkout mq-rest-admin-common" step.

- [ ] **Step 2: Commit**

```
st-commit --type refactor --scope docs-deploy --message "remove domain-specific checkout-common inputs" --agent claude
```

### Task 11: Refactor `version-bump-pr` composite action

**Files:**
- Modify: `actions/publish/version-bump-pr/action.yml`

Replace caller-provided regex configuration with `st-version bump`,
which reads `standard-tooling.toml` and knows per-language version
file conventions. Add automatic lockfile maintenance. The calling
workflow (`publish-release.yml`) installs standard-tooling before
invoking this action, so `st-version` is available in `$PATH`.

- [ ] **Step 1: Remove old version-parsing inputs**

Remove these input declarations from `action.yml`:

- `version-file`
- `version-regex`
- `version-replacement`
- `version-regex-multiline`
- `develop-version-command`

Keep: `current-version`, `post-bump-command`, `extra-files`,
`app-token`, `tracking-issue`, `pr-body-extra`.

- [ ] **Step 2: Replace develop version check with `st-version`**

Replace the "Check if develop already has next version" step. The
current step pipes `git show` through `develop-version-command`; the
new step uses a temporary worktree and `st-version show`:

```yaml
    - name: Check if develop already has next version
      id: check
      shell: bash
      run: |
        git fetch origin develop
        git worktree add --detach /tmp/develop-check origin/develop 2>/dev/null
        develop_version=$(cd /tmp/develop-check && st-version show 2>/dev/null) || true
        git worktree remove /tmp/develop-check 2>/dev/null || true
        if [ "$develop_version" = "${{ steps.next.outputs.version }}" ]; then
          echo "needed=false" >> "$GITHUB_OUTPUT"
        else
          echo "needed=true" >> "$GITHUB_OUTPUT"
        fi
```

- [ ] **Step 3: Replace regex version update with `st-version bump`**

Replace the "Update version file" step (the 20-line Python regex
script) with a single command. `st-version bump` handles both the
version file edit and lockfile maintenance (Task 3), so no separate
lockfile step is needed:

```yaml
    - name: Bump version
      if: steps.check.outputs.needed == 'true'
      shell: bash
      run: st-version bump
```

- [ ] **Step 4: Simplify commit step**

Replace the commit step. The old step staged `version-file` and
`extra-files` by name; the new step uses `git add -A` since the
branch is clean except for our bump and lockfile changes:

```yaml
    - name: Commit and push
      if: steps.check.outputs.needed == 'true'
      shell: bash
      run: |
        git add -A
        git commit -m "chore: bump version to ${{ steps.next.outputs.version }}"
        git push origin "${{ steps.next.outputs.branch }}"
```

- [ ] **Step 5: Commit**

```
st-commit --type refactor --scope version-bump-pr --message "use st-version bump instead of regex substitution" --agent claude
```

### Task 12: Refactor `publish-release.yml` to zero required inputs

**Files:**
- Modify: `.github/workflows/publish-release.yml`

Remove all required caller inputs (`ecosystem`, `version-command`,
`version-file`, `version-regex`, `version-replacement`,
`release-title`, `release-notes`, and all per-language version
inputs). The workflow detects the ecosystem from
`standard-tooling.toml`, uses `st-version` for version operations,
and derives build/registry commands per ecosystem. Also changes the
inner job name from `"publish: release"` to `"release"`.

- [ ] **Step 1: Replace inputs block**

Remove all current required inputs. Keep optional overrides for
genuine edge cases. The new inputs block:

```yaml
on:
  workflow_call:
    inputs:
      build-command:
        description: Override ecosystem-derived build command.
        type: string
        default: ""
      registry-publish-command:
        description: Override ecosystem-derived publish command.
        type: string
        default: ""
      attestation-subject-path:
        description: Glob for build provenance attestation. Leave empty to skip.
        type: string
        default: ""
      sbom-output-file:
        description: SBOM output path ($VERSION placeholder). Leave empty to skip.
        type: string
        default: ""
      release-artifacts:
        description: Files to attach to release ($VERSION placeholder).
        type: string
        default: ""
      post-bump-command:
        description: Override post-bump command for version-bump-pr.
        type: string
        default: ""
      extra-files:
        description: Additional files for version bump commit.
        type: string
        default: ""
    secrets:
      APP_ID:
        required: true
      APP_PRIVATE_KEY:
        required: true
      CARGO_REGISTRY_TOKEN:
        required: false
      RUBYGEMS_API_KEY:
        required: false
      CENTRAL_USERNAME:
        required: false
      CENTRAL_TOKEN:
        required: false
      GPG_PRIVATE_KEY:
        required: false
      GPG_PASSPHRASE:
        required: false
```

- [ ] **Step 2: Add standard-tooling install and ecosystem detection**

After the checkout step, add:

```yaml
      - name: Install standard-tooling
        run: pip install 'standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@v1.5'

      - name: Detect ecosystem
        id: ecosystem
        run: |
          lang=$(python3 -c "
          import tomllib, pathlib
          cfg = tomllib.loads(pathlib.Path('standard-tooling.toml').read_text())
          print(cfg['project']['primary-language'])
          ")
          echo "language=$lang" >> "$GITHUB_OUTPUT"
```

- [ ] **Step 3: Replace version extraction with `st-version`**

Replace the old `version-command` input usage:

```yaml
      - name: Extract version
        id: version
        run: |
          version=$(st-version show)
          echo "version=$version" >> "$GITHUB_OUTPUT"
          echo "tag=v$version" >> "$GITHUB_OUTPUT"
```

- [ ] **Step 4: Update ecosystem setup steps**

Change all `inputs.ecosystem` conditions to use the detected
language. Remove per-language version inputs — use defaults inline:

```yaml
      - name: Set up Python
        if: steps.ecosystem.outputs.language == 'python'
        uses: actions/setup-python@v6
        with:
          python-version: "3.14"

      - name: Set up Rust
        if: steps.ecosystem.outputs.language == 'rust'
        uses: actions-rust-lang/setup-rust-toolchain@v1
        with:
          toolchain: "1.93"

      - name: Set up Ruby
        if: steps.ecosystem.outputs.language == 'ruby'
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.4"
          bundler-cache: true

      - name: Set up Go
        if: steps.ecosystem.outputs.language == 'go'
        uses: actions/setup-go@v6
        with:
          go-version-file: go.mod

      - name: Set up Java
        if: steps.ecosystem.outputs.language == 'java'
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: "17"
          cache: maven
          server-id: central
          server-username: MAVEN_USERNAME
          server-password: MAVEN_PASSWORD
          gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
          gpg-passphrase: MAVEN_GPG_PASSPHRASE
```

- [ ] **Step 5: Add ecosystem command derivation**

Add after the tag check step, gated on new tag. Derives all three
ecosystem-specific commands (build, registry-check, publish) and the
credential guard condition. Python is excluded from `publish` because
PyPI uses OIDC trusted publishing via `pypa/gh-action-pypi-publish`
(a dedicated action step, not a shell command):

```yaml
      - name: Derive ecosystem commands
        if: steps.tag_check.outputs.exists == 'false'
        id: commands
        env:
          LANG: ${{ steps.ecosystem.outputs.language }}
        run: |
          build="${{ inputs.build-command }}"
          if [ -z "$build" ]; then
            case "$LANG" in
              python) build="uv build" ;;
              rust) build="cargo build --release" ;;
              ruby) build="gem build *.gemspec" ;;
              java) build="./mvnw -B package -DskipTests" ;;
              *) build="" ;;
            esac
          fi
          echo "build=$build" >> "$GITHUB_OUTPUT"

          case "$LANG" in
            python) registry_check="pip index versions \$(python3 -c \"import tomllib; print(tomllib.loads(open('pyproject.toml','rb').read().decode())['project']['name'])\" 2>/dev/null) 2>/dev/null | grep -qF \"\$VERSION\" && echo exists || echo not_found" ;;
            rust) registry_check="cargo search \$(grep '^name' Cargo.toml | head -1 | sed 's/.*\"\\(.*\\)\"/\\1/') 2>/dev/null | grep -qF \"\$VERSION\" && echo exists || echo not_found" ;;
            ruby) registry_check="gem list -r -e \$(grep 'spec.name' *.gemspec | sed \"s/.*'\\(.*\\)'/\\1/\") 2>/dev/null | grep -qF \"\$VERSION\" && echo exists || echo not_found" ;;
            *) registry_check="" ;;
          esac
          echo "registry-check=$registry_check" >> "$GITHUB_OUTPUT"

          publish="${{ inputs.registry-publish-command }}"
          if [ -z "$publish" ]; then
            case "$LANG" in
              rust) publish="cargo publish" ;;
              ruby) publish="gem push *.gem" ;;
              java) publish="./mvnw -B deploy -DskipTests" ;;
              *) publish="" ;;
            esac
          fi
          echo "publish=$publish" >> "$GITHUB_OUTPUT"

          # Credential guard — secret name to check before publish
          case "$LANG" in
            rust) echo "credential-secret=CARGO_REGISTRY_TOKEN" >> "$GITHUB_OUTPUT" ;;
            ruby) echo "credential-secret=RUBYGEMS_API_KEY" >> "$GITHUB_OUTPUT" ;;
            java) echo "credential-secret=CENTRAL_TOKEN" >> "$GITHUB_OUTPUT" ;;
            *) echo "credential-secret=" >> "$GITHUB_OUTPUT" ;;
          esac
```

- [ ] **Step 6: Update build, registry-check, and publish steps**

Replace `${{ inputs.build-command }}` with
`${{ steps.commands.outputs.build }}`,
`${{ inputs.registry-check-command }}` with
`${{ steps.commands.outputs.registry-check }}`, and
`${{ inputs.registry-publish-command }}` with
`${{ steps.commands.outputs.publish }}` in the Build, Check registry,
and Publish steps. Replace `${{ inputs.ecosystem }}` with
`${{ steps.ecosystem.outputs.language }}` in conditional checks.

Add the credential guard to the "Publish to registry" step:

```yaml
      - name: Publish to registry
        if: >-
          steps.ecosystem.outputs.language != 'python' &&
          steps.commands.outputs.publish != '' &&
          steps.tag_check.outputs.exists == 'false' &&
          steps.registry_check.outputs.status != 'exists'
        env:
          VERSION: ${{ steps.version.outputs.version }}
          CARGO_REGISTRY_TOKEN: ${{ secrets.CARGO_REGISTRY_TOKEN }}
          GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}
          MAVEN_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
          MAVEN_PASSWORD: ${{ secrets.CENTRAL_TOKEN }}
          MAVEN_GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
        run: |
          # Credential guard — skip gracefully when secrets are not configured
          guard="${{ steps.commands.outputs.credential-secret }}"
          if [ -n "$guard" ]; then
            val=$(printenv "$guard" 2>/dev/null || true)
            if [ -z "$val" ]; then
              echo "::notice::${guard} not configured — skipping publish"
              exit 0
            fi
          fi
          ${{ steps.commands.outputs.publish }}
```

- [ ] **Step 7: Update tag-and-release call**

Remove `release-title` and `release-notes` inputs — the action now
auto-derives these from Task 9:

```yaml
      - name: Tag and release
        if: steps.tag_check.outputs.exists == 'false'
        uses: wphillipmoore/standard-actions/actions/publish/tag-and-release@develop
        with:
          version: ${{ steps.version.outputs.version }}
          release-artifacts: ${{ steps.resolved.outputs.release-artifacts }}
```

- [ ] **Step 8: Update version-bump-pr call**

Remove old inputs — the action now uses `st-version` internally
from Task 11:

```yaml
      - name: Version bump PR
        if: steps.tag_check.outputs.exists == 'false'
        uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop
        with:
          current-version: ${{ steps.version.outputs.version }}
          post-bump-command: ${{ inputs.post-bump-command }}
          extra-files: ${{ inputs.extra-files }}
          app-token: ${{ steps.app-token.outputs.token }}
```

- [ ] **Step 9: Change inner job name**

Change the inner job name for the check name convention:

```yaml
jobs:
  publish:
    name: "release"
```

This produces `publish / release` when called by a consuming repo
with job key `publish`.

- [ ] **Step 10: Commit**

```
st-commit --type refactor --scope publish-release --message "derive all inputs from standard-tooling.toml, zero required caller inputs" --agent claude
```

### Task 13: Update standard-actions' own `publish.yml`

**Files:**
- Modify: `.github/workflows/publish.yml`

Standard-actions' own publish workflow stays bespoke (due to the
`freeze-internal-refs` step) and keeps the filename `publish.yml`.
Unlike `publish-docs.yml` (Task 7), dual triggers cannot work here
because the bespoke workflow is structurally different from the
reusable one — it needs an app token at checkout (for pushing
workflow file changes), has the freeze step, and does not
build/publish to a registry. These are fundamentally different job
structures that cannot share a file.

- [ ] **Step 1: Update publish.yml contents**

Apply these changes to `.github/workflows/publish.yml`:

1. Change job name from `"publish: release"` to
   `"publish / release"` (direct name since this is not a reusable
   workflow call)
2. Add a standard-tooling installation step after checkout (needed
   by version-bump-pr which now uses `st-version`):

```yaml
      - name: Install standard-tooling
        run: pip install 'standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@v1.5'
```

3. Remove `release-title` and `release-notes` from the
   tag-and-release call (use auto-derived defaults from Task 9)
4. Simplify the version-bump-pr call — remove `version-file`,
   `version-regex`, `version-replacement`, `develop-version-command`:

```yaml
      - name: Version bump PR
        if: steps.tag_check.outputs.exists == 'false'
        uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop
        with:
          current-version: ${{ steps.version.outputs.version }}
          app-token: ${{ steps.app-token.outputs.token }}
```

- [ ] **Step 2: Commit**

```
st-commit --type refactor --message "update publish.yml to use refactored composite actions" --agent claude
```

### Task 14: Update `standard-tooling.toml` with `[publish]` section

**Files:**
- Modify: `standard-tooling.toml`

- [ ] **Step 1: Add publish config**

```toml
[publish]
release = true
docs = true
```

- [ ] **Step 2: Commit**

```
st-commit --type chore --scope config --message "add [publish] section to standard-tooling.toml" --agent claude
```

### Task 15: Release standard-actions

- [ ] **Step 1: Validate locally**

Run: `st-docker-run -- st-validate-local`
Expected: all checks pass

- [ ] **Step 2: Create PR and merge**

Use the standard PR workflow. The PR should reference issue #318.

- [ ] **Step 3: Cut release from main**

The publish workflow on main handles tagging and release creation.

---

## Phase 3: Fleet rollout

> **Prereq:** Phase 2 released (standard-actions at new version)

### Task 16: Create follow-up issues

Create the following issues before starting the per-repo rollout:

- [ ] **Step 1: Create issues in standard-tooling**

| Title | Description |
|---|---|
| `feat: dev docs preview from develop merges` | Evaluate publishing development docs from develop merges to a separate path for QA before release (ref: spec #328) |
| `feat: v2.0 auto-generated API docs` | Revisit mkdocstrings (Python), Javadoc (Java), and equivalents for Ruby/Go/Rust |

- [ ] **Step 2: Create issue in mq-rest-admin-common**

| Title | Description |
|---|---|
| `feat: family-specific docs workflow for common fragments` | Implement reusable workflow or `pre-deploy-command` pattern for mq-rest-admin repos that need the common fragments checkout |

- [ ] **Step 3: Create issue in mq-rest-admin-java**

| Title | Description |
|---|---|
| `fix: remove dead javadoc generation step from docs workflow` | The `./mvnw javadoc:javadoc` step generates Javadoc that is not wired into the mkdocs site |

### Task 17: Per-repo migration

For each consuming repo with `standard-tooling.toml`, apply the
following checklist. Each repo is a single atomic PR.

**Repos with both publish and docs:**
standard-tooling, standard-tooling-plugin, standard-tooling-docker,
mq-rest-admin-python, mq-rest-admin-ruby, mq-rest-admin-go,
mq-rest-admin-java, mq-rest-admin-rust, mq-rest-admin-common,
mq-rest-admin-dev-environment, mq-rest-admin-template,
ai-research-methodology

**Repos with docs only:**
standards-and-conventions, pymqpcf

**Out of scope:**
the-infrastructure-mindset (non-versioned blog site)

#### Migration checklist (per repo)

- [ ] Add `[publish]` section to `standard-tooling.toml`
- [ ] Update `[dependencies].standard-tooling` to new version
- [ ] Delete `.github/workflows/docs.yml`
- [ ] Create `.github/workflows/publish-docs.yml` (thin caller):

```yaml
name: Publish docs
on:
  push:
    branches: [develop, main]
  workflow_dispatch:
permissions:
  contents: write
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-docs.yml@<new-tag>
```

- [ ] If repo has a publish workflow — delete `.github/workflows/publish.yml`
- [ ] If repo has a publish workflow — create `.github/workflows/publish-release.yml`:

```yaml
name: Publish release
on:
  push:
    branches: [main]
permissions:
  attestations: write
  contents: write
  id-token: write
  pull-requests: write
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@<new-tag>
    secrets: inherit
```

- [ ] If Python repo — remove `requirements.txt` and `requirements-dev.txt`
  from version control (if generated by `uv export`)
- [ ] If Python repo — remove `post-bump-command` and `extra-files` from
  the old publish.yml (now handled by `st-version bump`)
- [ ] Commit all changes in a single commit (old + new files together)
- [ ] Create PR referencing this migration

#### Special handling

- **mq-rest-admin-python**: Add `pre-deploy-command` to `publish-docs.yml`
  caller for `uv sync --frozen --group docs`. This keeps mkdocstrings
  working until the v2.0 auto-generated docs issue is resolved.
- **mq-rest-admin-java**: Do NOT include `./mvnw javadoc:javadoc` in
  the new workflow. The dead step is intentionally dropped.
- **mq-rest-admin family (all 5 language repos)**: Add
  `pre-deploy-command` for cloning mq-rest-admin-common fragments,
  until the family-specific workflow issue is resolved.
- **standard-tooling**: Has a bespoke `publish.yml` that does not use
  the reusable workflow. Migrate it to use `publish-release.yml` with
  `secrets: inherit` (it uses `ecosystem: python` but does not publish
  to PyPI — the reusable workflow handles this when
  `registry-publish-command` is empty).
