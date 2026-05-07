# Validation

## Canonical command

```bash
st-docker-run -- st-validate
```

This runs all validation inside the `ghcr.io/wphillipmoore/dev-base:latest`
container, which has every required tool pre-installed. No manual host
installs needed beyond the standard-tooling host tool.

## Architecture

`st-validate` reads `primary_language` from `standard-tooling.toml` and runs
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
