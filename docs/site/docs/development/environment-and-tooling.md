# Environment and Tooling

## Git hooks

Configure the repository to use the shared git hooks:

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit hook that prevents direct commits to protected
branches (`main`, `develop`).

## Host prerequisites

Install the vergil-tooling host tool, which provides `vrg-docker-run`,
`vrg-commit`, `vrg-validate`, and other workflow commands:

```bash
uv tool install 'vergil-tooling @ git+https://github.com/vergil-project/vergil-tooling@v1.4'
```

Docker must be running for `vrg-docker-run` to work.

## Validation and development tools

All validation tools (actionlint, shellcheck, markdownlint, yamllint) and
documentation tools (mkdocs-material, mike) are pre-installed in the
`ghcr.io/vergil-project/dev-base:latest` container image. No manual host
installs are needed — `vrg-docker-run` pulls and runs this image
automatically.

```bash
vrg-docker-run -- vrg-validate             # Run all validation checks
vrg-docker-run -- mkdocs serve -f docs/site/mkdocs.yml   # Preview docs locally
vrg-docker-run -- mkdocs build -f docs/site/mkdocs.yml --strict  # Strict docs build
```
