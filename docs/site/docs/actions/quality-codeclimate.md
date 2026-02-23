# quality/codeclimate

Uploads test coverage data to Qlty Cloud (formerly Code Climate) for coverage
tracking, trend analysis, and PR coverage comments.

> **Status**: Optional, advisory gate — currently in limited beta on the
> mq-rest-admin language implementation repos (Python, Go, Java). Qlty Cloud's
> free tier provides 500 analysis minutes/month for open-source projects.
> Language-specific tooling (ruff, mypy, golangci-lint, spotbugs, etc.) remains
> the primary enforcement mechanism.

## Usage

There are two recommended deployment patterns:

1. **PR analysis** — Add a `codeclimate` job to your CI workflow (`ci.yml`) so
   every pull request receives a Qlty coverage comment.
2. **Post-merge baseline** — Add a dedicated `codeclimate.yml` workflow triggered
   on `push` to `develop` so the Qlty Cloud dashboard stays current after each
   merge.

Both patterns are shown in the examples below.

### PR job (in ci.yml)

```yaml
- uses: wphillipmoore/standard-actions/actions/quality/codeclimate@develop
  with:
    files: "coverage.lcov"
```

### Post-merge workflow (codeclimate.yml)

```yaml
name: Code Climate

on:
  push:
    branches:
      - develop

permissions:
  contents: read
  id-token: write

concurrency:
  group: codeclimate
  cancel-in-progress: false

jobs:
  codeclimate:
    name: "quality: codeclimate"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      # ... language setup and test/coverage steps ...
      - uses: wphillipmoore/standard-actions/actions/quality/codeclimate@develop
        with:
          files: "coverage.lcov"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `files` | **Yes** | — | Coverage report file path(s), comma-separated or glob pattern. |
| `format` | No | `""` | Coverage format (auto-detected if omitted): clover, cobertura, coverprofile, jacoco, lcov, simplecov. |
| `tag` | No | `""` | Coverage tag to identify this upload (e.g., `unit`, `integration`). |
| `add-prefix` | No | `""` | Prefix to prepend to file paths in the coverage report. |
| `strip-prefix` | No | `""` | Prefix to strip from file paths in the coverage report. |

## Permissions

- `contents: read`
- `id-token: write` — Required for OIDC authentication with Qlty Cloud.

## Behavior

1. **Upload coverage to Qlty Cloud** — Delegates to
   `qltysh/qlty-action/coverage@v2` with `oidc: true` and the caller-provided
   inputs. OIDC authentication eliminates the need for any stored tokens or
   secrets.

Upload failures do not break CI (`skip-errors: true` is the upstream default).

## Examples

### Python with pytest coverage (LCOV)

```yaml
jobs:
  codeclimate:
    name: "quality: codeclimate"
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v5
        with:
          python-version: "3.14"
      - run: pip install -e ".[dev]" && pytest --cov --cov-report=lcov
      - uses: wphillipmoore/standard-actions/actions/quality/codeclimate@develop
        with:
          files: "coverage.lcov"
```

### Go with native coverage

```yaml
jobs:
  codeclimate:
    name: "quality: codeclimate"
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-go@v6
        with:
          go-version-file: go.mod
      - run: go test -race -count=1 -coverprofile=coverage.out ./...
      - uses: wphillipmoore/standard-actions/actions/quality/codeclimate@develop
        with:
          files: "coverage.out"
          format: "coverprofile"
```

### Java with JaCoCo

```yaml
jobs:
  codeclimate:
    name: "quality: codeclimate"
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: "21"
      - run: ./mvnw verify -B
      - uses: wphillipmoore/standard-actions/actions/quality/codeclimate@develop
        with:
          files: "target/site/jacoco/jacoco.xml"
          format: "jacoco"
          add-prefix: "src/main/java/"
```

## Qlty Cloud configuration

- **GitHub App** — Install the [Qlty Cloud GitHub
  App](https://github.com/apps/qlty) on your GitHub account or organization.
  This enables PR coverage comments and dashboard access.
- **Repository import** — Import each repository in Qlty Cloud at
  [qlty.io](https://qlty.io) to enable coverage tracking.
- **Disable automatic analysis** — Under each project's settings in Qlty Cloud,
  disable automatic analysis if you are using CI-based coverage upload
  exclusively.
- **OIDC authentication** — No tokens or secrets are required. The calling
  workflow must include `id-token: write` in its permissions block. Qlty Cloud
  validates the GitHub OIDC token to authenticate the upload.
- **Quality gates** — Qlty Cloud provides configurable quality gates for
  coverage thresholds. Coverage gate results appear as PR comments.

## Limitations

- **OIDC only** — This action does not support token-based authentication. The
  calling workflow must be able to request OIDC tokens (`id-token: write`).
- **Fork PRs** — Forks cannot request OIDC tokens for the upstream repository,
  so coverage upload will be skipped (non-fatal due to `skip-errors: true`).
- **Analysis minutes** — The free tier provides 500 analysis minutes per month
  for open-source projects. Usage beyond this limit requires a paid plan.
