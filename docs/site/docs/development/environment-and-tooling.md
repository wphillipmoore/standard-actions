# Environment and Tooling

## Git hooks

Configure the repository to use the shared git hooks:

```bash
git config core.hooksPath scripts/git-hooks
```

This enables the pre-commit hook that prevents direct commits to protected
branches (`main`, `develop`).

## External tooling

The following tools are required for local development and validation:

### Validation tools

| Tool | Install command | Purpose |
| ------ | ---------------- | --------- |
| `actionlint` | `brew install actionlint` | GitHub Actions workflow linter |
| `shellcheck` | `brew install shellcheck` | Shell script static analysis |
| `markdownlint` | `npm install --global markdownlint-cli` | Markdown formatting linter |

### Documentation tools

| Tool | Install command | Purpose |
| ------ | ---------------- | --------- |
| `mkdocs-material` | `pip install mkdocs-material` | MkDocs with Material theme |
| `mike` | `pip install mike` | Versioned documentation deployment |

### Local documentation preview

To preview the documentation site locally:

```bash
mkdocs serve -f docs/site/mkdocs.yml
```

To verify the build with strict mode (catches broken links and warnings):

```bash
mkdocs build -f docs/site/mkdocs.yml --strict
```
