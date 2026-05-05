# docs-deploy

Deploys MkDocs documentation using mike for versioned documentation. Handles
git configuration, version detection, and mike deploy/set-default.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/docs-deploy@v1.5
  with:
    version-command: cat VERSION | cut -d. -f1,2
    mkdocs-config: docs/site/mkdocs.yml
    mike-command: mike
    checkout-common: "false"
    checkout-common-ref: develop
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `version-command` | **Yes** | — | Shell command to extract the version string on main (e.g. `cat VERSION`, `grep -oP ... version.go`). |
| `mkdocs-config` | No | `docs/site/mkdocs.yml` | Path to mkdocs.yml configuration file. |
| `mike-command` | No | `mike` | Command to run mike. Set to `uv run mike` for Python repos that manage their own dependencies. When not `mike`, the action skips Python setup and MkDocs installation. |
| `checkout-common` | No | `false` | Whether to checkout mq-rest-admin-common. |
| `checkout-common-ref` | No | `develop` | Ref to checkout for mq-rest-admin-common. |

## Permissions

- `contents: write` (required for pushing to the `gh-pages` branch)

## Behavior

1. **Checkout common** (optional) — If `checkout-common` is `true`, checks out
   the `mq-rest-admin-common` repository for shared documentation fragments.
2. **Set up Python 3.12** — Only when `mike-command` is `mike` (default).
3. **Install MkDocs and mike** — `pip install mkdocs-material mike`. Skipped
   when a custom `mike-command` is provided.
4. **Configure git identity** — Sets the git user to `github-actions[bot]` for
   the deploy commit.
5. **Determine version** — On `main`, runs the `version-command` to extract the
   version and sets `alias=latest`. On all other branches, sets `version=dev`
   with no alias.
6. **Deploy docs** — On `main`, runs `mike deploy --push --update-aliases
   <version> latest` followed by `mike set-default --push latest`. On other
   branches, runs `mike deploy --push dev`.

## Examples

### Standard library deployment

```yaml
name: Documentation
on:
  push:
    branches: [develop, main]
permissions:
  contents: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: wphillipmoore/standard-actions/actions/docs-deploy@v1.5
        with:
          version-command: cat VERSION | cut -d. -f1,2
```

### Python repo with uv-managed dependencies

```yaml
- uses: wphillipmoore/standard-actions/actions/docs-deploy@v1.5
  with:
    version-command: cat VERSION | cut -d. -f1,2
    mike-command: uv run mike
```

## GitHub configuration

- **GitHub Pages** — Enable GitHub Pages in repository settings with source set
  to **Deploy from a branch** and branch set to `gh-pages`.
- The `gh-pages` branch is created automatically by `mike deploy --push` on
  first run.
