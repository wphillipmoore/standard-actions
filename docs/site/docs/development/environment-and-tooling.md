# Environment and Tooling

## Git hooks

Configure the repository to use the shared git hooks:

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit hook that prevents direct commits to protected
branches (`main`, `develop`).

## Host prerequisites

Install the standard-tooling host tool, which provides `st-docker-run`,
`st-commit`, `st-validate`, and other workflow commands:

```bash
uv tool install 'standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@v1.4'
```

Docker must be running for `st-docker-run` to work.

## Validation and development tools

All validation tools (actionlint, shellcheck, markdownlint, yamllint) and
documentation tools (mkdocs-material, mike) are pre-installed in the
`ghcr.io/wphillipmoore/dev-base:latest` container image. No manual host
installs are needed — `st-docker-run` pulls and runs this image
automatically.

```bash
st-docker-run -- uv run st-validate      # Run all validation checks
st-docker-run -- mkdocs serve -f docs/site/mkdocs.yml   # Preview docs locally
st-docker-run -- mkdocs build -f docs/site/mkdocs.yml --strict  # Strict docs build
```
