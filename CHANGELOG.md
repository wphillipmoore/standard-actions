# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.3.2] - 2026-04-27

### Bug fixes

- use Issues API instead of Search API for tracking-issue lookup

## [1.3.1] - 2026-04-27

### Features

- print findings table to stdout in addition to SARIF

## [1.3.0] - 2026-04-27

### Bug fixes

- inline helper python scripts to fix container-job failure (#204)
- add safe.directory '*' for container workspace ownership (#206)
- use App token throughout publish.yml so freeze-refs commit can be pushed

### Documentation

- clarify install paths and verification error (#202)

### Features

- freeze internal @develop refs at tag-cut time

## [1.2.1] - 2026-04-24

### Bug fixes

- use env vars + quoted heredoc in version-bump-pr Update step

### Release

- 1.1.3 (#190)

## [1.2.0] - 2026-04-24

### Features

- drop auto-merge from version-bump-pr composite (bump 1.2.0) (#193)

## [1.1.3] - 2026-04-23

### Bug fixes

- pin markdownlint-cli@0.41.0, add run-codeql flag (#172) (#173)
- rename dev-docs container references to dev-base (#182)
- stabilize version-bump-pr back-merge and docs-deploy container cwd (#188)

### CI

- remove standard-tooling setup hacks from standards-compliance (#179)

### Features

- add shared publish-release reusable workflow (#163)
- make docs-deploy container-aware (#174)
- adopt git worktree convention for parallel AI agent development (#184)

## [1.1.2] - 2026-03-01

### Bug fixes

- fix version-bump regex and correct VERSION to 1.1.2 (#136)
- create placeholder releases/index.md when no releases exist (#148)
- install Trivy binary directly to avoid setup-trivy cache fallback failure (#152)
- use setup-trivy with cache disabled instead of manual binary download (#153)
- replace aquasecurity GitHub actions with Docker-based Trivy execution (#154)

### Documentation

- document run-standards and run-security two-flag pattern (#138)
- add Rust Library to required checks matrix (#142)
- add ci: type-check to required checks matrix (#143)
- update tag protection ruleset docs for rolling tag support (#158)

### Features

- add rolling vX.Y minor tags to tag-and-release action (#149)

## [1.1.1] - 2026-02-26

### Bug fixes

- bootstrap standards documentation
- add autobuild step for compiled language support
- sync shared tooling to v1.0.2
- sync lint scripts from standards-and-conventions (#28)
- pass release notes via env var to prevent shell injection (#44)
- replace mapfile with bash 3.2-compatible alternative (#49)
- set dev as default version when no default exists (#57)
- remove redundant close/reopen cycle (#66)
- update add-to-project action to v1.0.2 (#69)
- resolve event-payload race in version-bump-pr issue linkage (#73)
- add diagnostics to version-bump-pr tracking issue resolution (#81)
- handle missing version on main in version-divergence check (#87)
- search all issue states when resolving bump PR tracking issue (#95)
- add semgrep-language input for Go compatibility (#101)
- preserve severity filter in SARIF output for Trivy scans (#123)
- install pyyaml when mike-command is not mike (#128)
- correct corrupted VERSION file to 1.1.1 (#133)

### CI

- add publish workflow for tag, release, and version bump (#131)

### Documentation

- align standards entrypoint with repo type
- add repository bootstrap guide
- ban MEMORY.md usage in CLAUDE.md (#48)
- ban heredocs in shell commands (#50)
- update CI gate docs to reflect actual state (#56)
- add repository rulesets documentation (#58)
- add branch targeting guidance to rulesets page (#59)
- add branch targeting guidance to rulesets page (#60)
- add repository configuration documentation (#76)
- update SonarCloud documentation with lessons learned and beta status (#83)
- document version matrix for unit and integration tests, add Ruby column, explain duplicate security checks (#88)
- replace stale script references with st-* commands (#94)
- add publish workflow ordering guide (#117)
- fix secret gate example in publish workflow guide (#118)
- add version bump PR guidance to publish workflow guide (#121)

### Features

- add initial composite actions for docs-only detection, standards compliance, and Python setup (#10)
- exempt docs/site from structural markdown checks (#11)
- add CodeQL SAST composite action
- add Trivy and Semgrep composite actions for Tier 2 security tooling
- add shared tooling staleness gate and sync scripts
- add CI workflow, CLAUDE.md, and repository infrastructure (#24)
- add add-to-project workflow for standards project
- add ci and build to allowed conventional commit types (#32)
- add composite action for MkDocs/mike deployment (#33)
- add VERSION file for release automation (#37)
- add reusable composite actions for tag-and-release, version-bump-pr, and version-divergence (#41)
- add category prefixes to CI job names (#45)
- adopt validate_local.sh dispatch architecture (#51)
- add MkDocs documentation site with action reference and CI gate specs (#53)
- migrate to PATH-based standard-tooling consumption (#77)
- add SonarCloud composite action (#82)
- add Code Climate (Qlty) coverage upload action (#84)
- add reusable security and standards workflow (#99)
- add sarif-category input for unique SARIF uploads (#115)
- add trivyignores input for suppressing known-acceptable CVEs (#120)

### Refactoring

- remove commit message validation from CI (#78)
- remove docs-only-detect action and CI special-casing (#111)
