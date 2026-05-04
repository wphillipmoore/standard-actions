# ci-test

Unit and integration test workflow.

## Inputs

| Input | Type | Required | Default | Description |
| ------- | ------ | ---------- | --------- | ------------- |
| `language` | string | yes | — | Primary language of the repository |
| `versions` | string | yes | — | JSON array of language versions (e.g., `'["3.12", "3.13"]'`) |
| `integration-tests` | boolean | no | `false` | Enable integration test jobs |

## Jobs and check names

| Job | Check name | Condition |
| ----- | ------------ | ----------- |
| `unit / <version>` | `CI Test / unit / <version>` | Always runs |
| `integration / <version>` | `CI Test / integration / <version>` | `integration-tests` is true |

## Usage

Unit tests only:

```yaml
jobs:
  test:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-test.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'
```

With integration tests:

```yaml
jobs:
  test:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-test.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'
      integration-tests: true
```

## Extension points

The `unit` and `integration` jobs provide version matrix scaffolds.
Consuming repositories customize these by forking the workflow or by
running language-specific test commands in a separate workflow.
