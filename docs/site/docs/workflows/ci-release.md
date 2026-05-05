# ci-release

Release gate verification workflow.

## Inputs

| Input | Type | Required | Default | Description |
| ------- | ------ | ---------- | --------- | ------------- |
| `language` | string | yes | — | Primary language of the repository |
| `run-release` | boolean | no | `true` | Run the version-bump verification job |

## Jobs and check names

| Job | Check name | Condition |
| ----- | ------------ | ----------- |
| `version-bump` | `CI Release / version-bump` | `run-release` is true |

## Usage

```yaml
jobs:
  release:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-release.yml@v1.5
    with:
      language: python
```

To skip release gates (e.g., for infrastructure repos that don't version):

```yaml
jobs:
  release:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-release.yml@v1.5
    with:
      language: shell
      run-release: false
```
