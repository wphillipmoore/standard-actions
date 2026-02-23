# quality/sonarcloud

Runs SonarQube Cloud (SonarCloud) static analysis for code quality, security
vulnerabilities, and maintainability across all supported languages.

## Usage

```yaml
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
          python-version: "3.13"
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

### Go with Cobertura coverage

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
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Run tests with coverage
        run: |
          go test -coverprofile=coverage.out ./...
          go install github.com/boumenot/gocover-cobertura@latest
          gocover-cobertura < coverage.out > coverage.xml
      - uses: wphillipmoore/standard-actions/actions/quality/sonarcloud@develop
        with:
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          organization: my-org
          project-key: my-org_my-repo
          sources: "."
          tests: "."
          coverage-report: "coverage.xml"
```

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
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
      - run: mvn -B verify
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

## GitHub configuration

- **SonarCloud organization** — Link your GitHub organization at
  [sonarcloud.io](https://sonarcloud.io) and note the organization key.
- **Project setup** — Import the repository in SonarCloud to obtain the project
  key (typically `<org>_<repo>`).
- **Authentication token** — Generate a token under **My Account > Security** in
  SonarCloud and store it as a repository or organization secret named
  `SONAR_TOKEN`.
- **Quality gate** — Configure quality gate thresholds in SonarCloud project
  settings. The default "Sonar way" gate covers new code coverage, duplications,
  reliability, security, and maintainability ratings.
- **Fetch depth** — The calling workflow must check out with `fetch-depth: 0` so
  SonarCloud can perform blame-based new code detection.
