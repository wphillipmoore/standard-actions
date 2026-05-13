# Validation

## Canonical command

```bash
vrg-docker-run -- vrg-validate
```

This runs all validation inside the `ghcr.io/vergil-project/dev-base:latest`
container, which has every required tool pre-installed. No manual host
installs needed beyond the vergil-tooling host tool.

## Architecture

`vrg-validate` reads `primary_language` from `vergil.toml` and runs
common checks followed by language-specific checks from the built-in command
registry. Common checks include repo-profile validation, markdownlint,
shellcheck, yamllint, and actionlint.

## Tooling

All validation tools are pre-installed in the dev-base container image:

| Tool | Purpose |
| --- | --- |
| `actionlint` | GitHub Actions workflow linter |
| `shellcheck` | Shell script static analysis |
| `markdownlint` | Markdown formatting linter |
| `yamllint` | YAML formatting linter |

No host-level installs of these tools are required.
