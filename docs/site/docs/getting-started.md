# Getting Started

## Consuming actions

Reference actions from this repository using the full path with a branch or tag
pin:

```yaml
uses: wphillipmoore/standard-actions/actions/<action-path>@develop
```

!!! note "Branch pinning"
    During the pre-release period (0.x), all consumers pin to `@develop`.
    Versioned tag-based pinning will be available once publishing automation is
    complete.

## Minimal workflow example

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [develop]

permissions:
  contents: read

jobs:
  docs-only:
    runs-on: ubuntu-latest
    outputs:
      docs-only: ${{ steps.detect.outputs.docs-only }}
    steps:
      - uses: actions/checkout@v6
      - id: detect
        uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop

  standards:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: wphillipmoore/standard-actions/actions/standards-compliance@develop
```

## Permissions

Each action documents its required workflow permissions. Common patterns:

| Permission | Actions that require it |
| ------------ | ---------------------- |
| `contents: read` | docs-only-detect, standards-compliance |
| `contents: write` | docs-deploy, publish/tag-and-release, publish/version-bump-pr |
| `security-events: write` | security/codeql, security/semgrep, security/trivy |

## Self-referencing CI

This repository uses **local paths** (`./actions/...`) rather than remote
references in its own CI workflow. This means changes to an action are validated
by the same PR that modifies them — no separate integration testing step is
needed.

Consuming repositories use the full remote reference
(`wphillipmoore/standard-actions/actions/...@develop`).
