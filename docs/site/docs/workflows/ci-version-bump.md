# ci-version-bump

Version divergence gate workflow.

## Inputs

| Input | Type | Required | Default | Description |
| ------- | ------ | ---------- | --------- | ------------- |
| `language` | string | yes | — | Primary language of the repository |
| `run-release` | boolean | no | `true` | Run the version-bump verification job |

## Jobs and check names

| Job | Check name | Condition |
| ----- | ------------ | ----------- |
| `version-bump` | `CI Version Bump / version-bump` | `run-release` is true |

## Usage

```yaml
jobs:
  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: python
```

To skip version gates (e.g., for infrastructure repos that don't version):

```yaml
jobs:
  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: shell
      run-release: false
```
