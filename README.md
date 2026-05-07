# Standard Actions

Shared GitHub Actions library for reusable CI and automation across
repositories.

## Table of Contents

- [Purpose](#purpose)
- [Repository layout](#repository-layout)
- [Branching and releases](#branching-and-releases)
- [Versioning](#versioning)
- [Validation](#validation)

## Purpose

Provide a centralized, versioned set of GitHub Actions that can be reused across
application and library repositories without workflow drift.

## Repository layout

```text
actions/
  <action-name>/
    action.yml
    README.md
    scripts/
```

## Branching and releases

- `develop` is the integration branch.
- Release branches are named `release/<version>` (e.g., `release/1.4.1`).
- Releases are tagged on `main` after the release PR merges.

## Versioning

- Repository-level SemVer tags (for example, `v1`, `v1.2.0`).
- Consumers must pin actions by tag or commit SHA.

## Documentation

Full documentation is available at
<https://wphillipmoore.github.io/standard-actions/>.

## Validation

```bash
st-docker-run -- uv run st-validate
```
