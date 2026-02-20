# Validation

## Canonical command

```bash
scripts/dev/validate_local.sh
```

This is the single entry point for all local validation. Run it before
committing to catch issues early.

## Dispatch architecture

`validate_local.sh` uses a dispatch architecture that separates common
validation (shared across repositories) from repository-specific checks:

1. **Common checks** — Sourced from `standard-tooling` via the sync mechanism.
   These include markdownlint, shellcheck, and other universal validations.
2. **Custom checks** — Repository-specific validations defined locally, such as
   actionlint for this repository's workflow files.

The sync mechanism (`scripts/dev/sync-tooling.sh`) keeps the common validation
scripts in sync with the canonical versions in `standard-tooling`. The
`standards-compliance` action validates this staleness in CI.

## Docs-only validation

For changes that only affect documentation:

```bash
scripts/dev/validate_docs.sh
```

This runs a subset of checks relevant to documentation changes (primarily
markdownlint).

## Tooling dependencies

Validation requires the following tools to be installed:

- `actionlint` — GitHub Actions workflow linting
- `shellcheck` — Shell script static analysis
- `markdownlint` — Markdown formatting

See [Environment and Tooling](environment-and-tooling.md) for installation
instructions.
