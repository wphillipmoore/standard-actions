# Getting Started

## Consuming actions

Reference actions from this repository using the full path with a rolling minor
tag pin:

```yaml
uses: wphillipmoore/standard-actions/actions/<action-path>@v1.4
```

!!! note "Tag pinning"
    Pin to a rolling minor tag (e.g., `@v1.4`) to automatically receive patch
    releases. Pin to an exact tag (e.g., `@v1.4.1`) for full reproducibility.

## Minimal workflow example

```yaml
name: CI - Test and Validate

on:
  pull_request:

permissions:
  contents: read

jobs:
  standards:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: wphillipmoore/standard-actions/actions/standards-compliance@v1.4
```

## Permissions

Each action documents its required workflow permissions. Common patterns:

| Permission | Actions that require it |
| ------------ | ---------------------- |
| `contents: read` | standards-compliance |
| `contents: write` | docs-deploy, publish/tag-and-release, publish/version-bump-pr |
| `security-events: write` | security/codeql, security/semgrep, security/trivy |

## Self-referencing CI

This repository uses **local paths** (`./actions/...`) rather than remote
references in its own CI workflow. This means changes to an action are validated
by the same PR that modifies them — no separate integration testing step is
needed.

Consuming repositories use the full remote reference
(`wphillipmoore/standard-actions/actions/...@v1.4`).
