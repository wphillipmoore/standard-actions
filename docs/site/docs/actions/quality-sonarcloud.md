# quality/sonarcloud

Runs SonarQube Cloud (SonarCloud) static analysis for code quality, security
vulnerabilities, and maintainability across all supported languages.

> **Status**: Optional, advisory gate — currently in limited beta on the
> mq-rest-admin language implementation repos (Python, Go, Java). SonarCloud's
> free tier does not support custom quality gates, so this action provides
> informational analysis rather than enforcement. Language-specific tooling
> (ruff, mypy, golangci-lint, spotbugs, etc.) remains the primary enforcement
> mechanism.

## Usage

There are two recommended deployment patterns:

1. **PR analysis** — Add a `sonarcloud` job to your CI workflow (`ci.yml`) so
   every pull request receives a SonarCloud quality gate comment.
2. **Post-merge baseline** — Add a dedicated `sonarcloud.yml` workflow triggered
   on `push` to `develop` so the SonarCloud project dashboard stays current
   after each merge.

Both patterns are shown in the examples below.

### PR job (in ci.yml)

```yaml
- uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
  with:
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    organization: my-org
    project-key: my-org_my-repo
    sources: "src"
    coverage-report: "coverage.xml"
```

### Post-merge workflow (sonarcloud.yml)

```yaml
name: SonarCloud

on:
  push:
    branches:
      - develop

permissions:
  contents: read

concurrency:
  group: sonarcloud
  cancel-in-progress: false

jobs:
  sonarcloud:
    name: "quality: sonarcloud"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      # ... language setup and test/coverage steps ...
      - uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
        with:
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          organization: my-org
          project-key: my-org_my-repo
          sources: "src"
          coverage-report: "coverage.xml"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `sonar-token` | **Yes** | — | SonarQube Cloud authentication token (from secrets). |
| `organization` | **Yes** | — | SonarCloud organization key. |
| `project-key` | **Yes** | — | SonarCloud project key. |
| `sources` | No | `"src"` | Comma-separated source directories. |
| `tests` | No | `""` | Comma-separated test directories. |
| `coverage-report` | No | `""` | Path to coverage report (format auto-detected by SonarCloud). |
| `java-binaries` | No | `""` | Path to compiled Java classes (required for Java projects). |
| `extra-args` | No | `""` | Additional sonar properties as `-D` flags, newline-separated. |

## Permissions

- `contents: read`

## Behavior

1. **Validate inputs** — Fails early if `sonar-token` is empty, which is the
   common case for fork PRs where secrets are not available.
2. **Build scanner arguments** — Constructs `-Dsonar.organization`,
   `-Dsonar.projectKey`, `-Dsonar.sources`, and conditional properties
   (`sonar.tests`, `sonar.coverage.reportPaths`, `sonar.java.binaries`) from
   inputs. Appends any `extra-args` lines.
3. **Run SonarQube Cloud scan** — Delegates to
   `SonarSource/sonarqube-scan-action@v5` with the assembled arguments and
   `SONAR_TOKEN` environment variable.

## Examples

### Python with pytest coverage

```yaml
jobs:
  sonarcloud:
    name: "quality: sonarcloud"
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: "3.14"
      - run: pip install -e ".[dev]" && pytest --cov --cov-report=xml
      - uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
        with:
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          organization: my-org
          project-key: my-org_my-repo
          sources: "src"
          tests: "tests"
          coverage-report: "coverage.xml"
```

### Go with native coverage

Go source and test files live in the same directory. Use `extra-args` to pass
the Go-specific coverage path and separate test files from source files using
inclusion/exclusion patterns.

```yaml
jobs:
  sonarcloud:
    name: "quality: sonarcloud"
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: actions/setup-go@v6
        with:
          go-version-file: go.mod
      - run: go test -race -count=1 -coverprofile=coverage.out ./...
      - uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
        with:
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          organization: my-org
          project-key: my-org_my-repo
          sources: "pkg"
          tests: "pkg"
          extra-args: >-
            -Dsonar.go.coverage.reportPaths=coverage.out
            -Dsonar.test.inclusions=**/*_test.go
            -Dsonar.exclusions=**/*_test.go
```

> **Important**: Do not set both `sources` and `tests` to `"."` — SonarCloud
> cannot index the same file in both sets. Scope to the package directory and
> use `sonar.test.inclusions` / `sonar.exclusions` to separate test files.

### Java with Maven

```yaml
jobs:
  sonarcloud:
    name: "quality: sonarcloud"
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: "21"
      - run: ./mvnw verify -B
      - uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
        with:
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          organization: my-org
          project-key: my-org_my-repo
          sources: "src/main/java"
          tests: "src/test/java"
          coverage-report: "target/site/jacoco/jacoco.xml"
          java-binaries: "target/classes"
```

## SonarCloud configuration

- **Account setup** — Log in at [sonarcloud.io](https://sonarcloud.io) with
  your GitHub account. For personal accounts, your GitHub username becomes the
  organization key.
- **Project import** — Import each repository in SonarCloud to obtain the
  project key (typically `<org>_<repo>`).
- **Disable automatic analysis** — Under each project's **Administration >
  Analysis Method**, turn off automatic analysis. CI-based analysis and
  automatic analysis cannot run simultaneously.
- **Authentication token** — Generate a user token under **My Account >
  Security** in SonarCloud. Store it as a GitHub secret named `SONAR_TOKEN` on
  each repository that uses this action.
- **Quality gate** — The free tier uses the default "Sonar way" quality gate,
  which covers new code coverage, duplications, reliability, security, and
  maintainability ratings. Custom quality gates require a paid plan.
- **Fetch depth** — The calling workflow must check out with `fetch-depth: 0` so
  SonarCloud can perform blame-based new code detection.
- **Branch mapping** — SonarCloud treats the branch from the first scan as the
  "main" branch. If your default branch is `develop`, the post-merge workflow
  will establish `develop` as the baseline for PR comparisons.

## Limitations

- **Custom quality gates** require the paid tier ($32/month for up to 110k lines
  of code, $190/month above that). The free tier only supports the default
  "Sonar way" gate.
- **Branch rename** — There is no straightforward way to change the main branch
  in SonarCloud after the first scan. Plan your post-merge workflow trigger
  accordingly.
- **Fork PRs** — Forks cannot access repository secrets, so the scan will fail
  gracefully at the input validation step.
