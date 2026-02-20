# security/trivy

Runs Trivy vulnerability scanning, SBOM generation, or container image scanning.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/security/trivy@develop
  with:
    scan-type: fs
    scan-ref: "."
    severity: "CRITICAL,HIGH"
    exit-code: "1"
    scanners: "vuln"
    output-file: "trivy-results.sarif"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `scan-type` | **Yes** | — | Scan mode: `fs` (filesystem vuln scan to SARIF), `sbom` (CycloneDX SBOM generation), or `image` (container image scan to SARIF). |
| `scan-ref` | No | `.` | Filesystem path or container image reference to scan. |
| `severity` | No | `CRITICAL,HIGH` | Comma-separated severity levels to report. |
| `exit-code` | No | `1` | Exit code when vulnerabilities are found (`0` = advisory only). |
| `scanners` | No | `vuln` | Comma-separated Trivy scanners to enable. |
| `output-file` | No | `trivy-results.sarif` | Output file path for SARIF or SBOM results. |

## Permissions

- `security-events: write` (required for SARIF upload when `scan-type` is `fs`
  or `image`)
- `contents: read`

## Behavior

The action branches based on `scan-type`:

### Filesystem scan (`fs`)

1. Runs `aquasecurity/trivy-action@0.34.0` with `scan-type: fs` against the
   specified `scan-ref`.
2. Outputs results in SARIF format.
3. Uploads the SARIF file to GitHub code scanning (category: `trivy-fs`).

### Image scan (`image`)

1. Runs `aquasecurity/trivy-action@0.34.0` with `scan-type: image` against the
   specified image reference.
2. Outputs results in SARIF format.
3. Uploads the SARIF file to GitHub code scanning (category: `trivy-image`).

### SBOM generation (`sbom`)

1. Runs `aquasecurity/trivy-action@0.34.0` with `scan-type: fs` and
   `format: cyclonedx`.
2. Outputs the SBOM to the specified output file. No SARIF upload.

## Examples

### Filesystem vulnerability scan

```yaml
jobs:
  trivy:
    name: "security: trivy"
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: wphillipmoore/standard-actions/actions/security/trivy@develop
        with:
          scan-type: fs
```

### Container image scan

```yaml
- uses: wphillipmoore/standard-actions/actions/security/trivy@develop
  with:
    scan-type: image
    scan-ref: "myapp:latest"
```

### SBOM generation (advisory only)

```yaml
- uses: wphillipmoore/standard-actions/actions/security/trivy@develop
  with:
    scan-type: sbom
    output-file: sbom.cdx.json
```

## GitHub configuration

- **GitHub Advanced Security (GHAS)** — Must be enabled for SARIF upload
  (`fs` and `image` scan types).
- **Code scanning alerts** — Results appear in **Security > Code scanning
  alerts** with categories `trivy-fs` or `trivy-image`.
