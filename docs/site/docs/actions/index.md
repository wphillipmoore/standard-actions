# Action Reference

All actions are composite GitHub Actions located under the `actions/` directory.
Each action is self-contained with an `action.yml` definition and optional
supporting scripts.

## Available actions

### CI & Validation

- **[standards-compliance](standards-compliance.md)** — Validates repository
  standards: markdown, PR linkage, auto-close keyword rejection, and repository
  profile.

### Documentation

- **[docs-deploy](docs-deploy.md)** — Deploys MkDocs documentation using mike
  for versioned documentation.

### Python

- **[python/setup](python-setup.md)** — Sets up Python, installs uv, and
  configures dependency caching.

### Security

- **[security/codeql](security-codeql.md)** — Runs GitHub CodeQL static
  analysis for a single language.
- **[security/semgrep](security-semgrep.md)** — Runs Semgrep SAST scanning with
  language-specific and cross-cutting security rulesets.
- **[security/trivy](security-trivy.md)** — Runs Trivy vulnerability scanning,
  SBOM generation, or container image scanning.

### Publishing

- **[publish/tag-and-release](publish-tag-and-release.md)** — Creates annotated
  git tags and GitHub Releases.
- **[publish/version-bump-pr](publish-version-bump-pr.md)** — Automates
  post-release version bump PRs.

### Release Gates

- **[release-gates/version-divergence](release-gates-version-divergence.md)** —
  Verifies that the PR branch version differs from the main branch version.
