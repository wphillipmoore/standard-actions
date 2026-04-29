# security/semgrep

Runs Semgrep static analysis with language-specific and cross-cutting security
rulesets.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/security/semgrep@v1.4
  with:
    language: python
    extra-config: "p/owasp-top-ten"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `language` | **Yes** | — | Language ruleset to enable (maps to `p/<language>`, e.g. `python`, `java`, `golang`). |
| `extra-config` | No | `""` | Additional Semgrep config strings, space-separated (e.g. `p/owasp-top-ten`). |

## Permissions

- `security-events: write` (required for uploading SARIF results)
- `contents: read`

## Behavior

1. **Install Semgrep** — Runs `pip install semgrep`.
2. **Run scan** — Executes `semgrep scan` with the following config rulesets:
    - `p/<language>` — Language-specific rules
    - `p/security-audit` — Cross-cutting security audit rules
    - `p/secrets` — Secret detection rules
    - Any additional rulesets from `extra-config`
3. **Upload SARIF** — Uploads the SARIF output file to GitHub code scanning
   using `github/codeql-action/upload-sarif@v4`, categorized as `semgrep`.
   This step runs even if the scan finds issues (`if: always()`).

## Examples

### Python Semgrep scan

```yaml
jobs:
  semgrep:
    name: "security: semgrep"
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: wphillipmoore/standard-actions/actions/security/semgrep@v1.4
        with:
          language: python
```

### Go with additional OWASP rules

```yaml
- uses: wphillipmoore/standard-actions/actions/security/semgrep@v1.4
  with:
    language: golang
    extra-config: "p/owasp-top-ten"
```

## GitHub configuration

- **GitHub Advanced Security (GHAS)** — Must be enabled for SARIF upload.
- **Code scanning alerts** — Results appear in the repository's **Security >
  Code scanning alerts** tab alongside CodeQL results.
