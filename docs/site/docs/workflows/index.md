# Reusable Workflows

v1.5.0 introduced reusable CI workflows that provide canonical job and check
names across all managed repositories. Each workflow bundles one or more
composite actions with the container, tooling, and permission setup needed
to run them.

## Why reusable workflows?

Composite actions run as steps within a caller-defined job. Reusable workflows
run as complete jobs, which means they control the job name that appears in
GitHub's checks UI. This guarantees consistent, canonical check names across
repositories — a requirement for pattern-based required status checks in
rulesets.

## Available workflows

| Workflow | File | Purpose |
| ---------- | ------ | --------- |
| [CI Security](ci-security.md) | `ci-security.yml` | Standards compliance and security scanning |
| [CI Quality](ci-quality.md) | `ci-quality.yml` | Common linting, language-specific lint and typecheck |
| [CI Audit](ci-audit.md) | `ci-audit.yml` | Dependency audit |
| [CI Test](ci-test.md) | `ci-test.yml` | Unit and integration tests |
| [CI Release](ci-release.md) | `ci-release.yml` | Release gate verification |

## Consuming a reusable workflow

Reference workflows using the full path to the workflow file with a rolling
minor tag pin:

```yaml
uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
```

!!! note "Tag pinning"
    The same tag pinning guidance applies as for composite actions. Pin to
    `@v1.5` for automatic patch releases, or `@v1.5.0` for full
    reproducibility.

## Permissions

Reusable workflows inherit permissions from the calling workflow. Callers must
declare the permissions each workflow needs at the job level:

```yaml
jobs:
  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: python
```

## Reference freezing

The workflow source files reference composite actions via `@develop` during
development. At release time, the publish workflow freezes all `@develop`
references to the release tag (e.g., `@v1.5.0`), ensuring that a pinned
workflow version uses the matching action versions.
