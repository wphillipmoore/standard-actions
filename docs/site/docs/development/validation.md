# Validation

## Canonical command

```bash
st-docker-run -- st-validate-local
```

This runs all validation inside the `ghcr.io/wphillipmoore/dev-base:latest`
container, which has every required tool pre-installed. No manual host
installs needed beyond the standard-tooling host tool.

## Dispatch architecture

`st-validate-local` uses a dispatch architecture that separates common
validation from repository-specific checks:

1. **Common checks** (`st-validate-local-common`) — repo-profile validation,
   markdown standards, shellcheck, and yamllint.
2. **Custom checks** (`scripts/bin/validate-local-custom`) — repository-specific
   validations defined locally (actionlint for this repository's workflow files).

## Tooling

All validation tools are pre-installed in the dev-base container image:

| Tool | Purpose |
| --- | --- |
| `actionlint` | GitHub Actions workflow linter |
| `shellcheck` | Shell script static analysis |
| `markdownlint` | Markdown formatting linter |
| `yamllint` | YAML formatting linter |

No host-level installs of these tools are required.
