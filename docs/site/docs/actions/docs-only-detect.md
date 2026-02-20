# docs-only-detect

Detects whether a pull request contains only documentation changes. For non-PR
events, always outputs `false`.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop
  id: detect
  with:
    docs-patterns: "docs/** README.md CHANGELOG.md *.md"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `docs-patterns` | No | `docs/** README.md CHANGELOG.md *.md` | Space-separated glob patterns that identify documentation files. |

## Outputs

| Name | Description |
| ------ | ------------- |
| `docs-only` | `true` if all changed files match docs patterns, `false` otherwise. |

## Permissions

- `contents: read` (default for `github.token`)

## Behavior

1. Checks if the triggering event is a `pull_request`. If not, outputs `false`
   and exits.
2. Fetches the list of changed files from the GitHub API using pagination.
3. If no files are found, outputs `false`.
4. Iterates through each changed file, matching against the configured glob
   patterns using shell `case` matching.
5. If any file does not match a docs pattern, outputs `false`. Otherwise
   outputs `true`.

## Examples

### Gate expensive jobs on docs-only detection

```yaml
jobs:
  docs-only:
    runs-on: ubuntu-latest
    outputs:
      docs-only: ${{ steps.detect.outputs.docs-only }}
    steps:
      - uses: actions/checkout@v6
      - id: detect
        uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop

  build:
    needs: docs-only
    runs-on: ubuntu-latest
    steps:
      - if: needs.docs-only.outputs.docs-only == 'true'
        run: echo "Docs-only changes; skipping build."
      - if: needs.docs-only.outputs.docs-only != 'true'
        uses: actions/checkout@v6
      # ... build steps with docs-only guards
```

### Custom docs patterns

```yaml
- uses: wphillipmoore/standard-actions/actions/docs-only-detect@develop
  id: detect
  with:
    docs-patterns: "docs/** *.md LICENSE .github/ISSUE_TEMPLATE/**"
```

## GitHub configuration

No special repository configuration is required. The action uses the default
`github.token` to query the pull request files API.
