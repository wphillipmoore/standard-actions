# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.5.9] - 2026-05-06

### Bug fixes

- complete .venv/bin PATH fix for all st-* invocations and add GHAS required checks

## [1.5.8] - 2026-05-06

### Bug fixes

- prepend .venv/bin to PATH before st-validate calls

## [1.5.6] - 2026-05-06

### Bug fixes

- skip uv tool install when consumer repo is standard-tooling

## [1.5.5] - 2026-05-06

### Bug fixes

- install dev dependencies in lint and typecheck jobs
- install dev dependencies in test and audit reusable workflows
- rename step from Install dev dependencies to Install dependencies

## [1.5.4] - 2026-05-06

### Bug fixes

- use relative action refs in CI workflows, freeze to tagged refs at publish time

## [1.5.3] - 2026-05-05

### Bug fixes

- remove || true from yamllint in ci-quality.yml
- remove || true from markdownlint, hadolint, and actionlint
- fix linter violations exposed by removing || true
- fix markdownlint violations in CI workflow reset design spec
- add safe.directory for container-based CI in version-divergence action
- add safe.directory to setup action for container-based CI
- always install standard-tooling from pinned tag, never skip

### CI

- pass container-suffix to ci-quality for shell language

### Documentation

- add design spec for CI workflow reset and unified validation
- apply pushback review to CI workflow reset design
- add implementation plan for CI workflow reset
- add st-version as explicit Phase 1 task in CI workflow reset plan
- apply alignment review fixes to CI workflow reset plan and spec

### Features

- implement ci-quality.yml with st-validate dispatch
- implement ci-test.yml with st-validate dispatch
- implement ci-audit.yml with st-validate dispatch
- implement ci-release.yml with st-version version-divergence gate
- add reusable setup/standard-tooling action and use it in all workflows

## [1.5.2] - 2026-05-05

### Bug fixes

- pin astral-sh/setup-uv to v8.1.0

### Documentation

- add design spec for publish and docs workflow rationalization
- apply pushback review to publish/docs rationalization spec
- add implementation plan for publish and docs rationalization
- apply alignment review fixes to publish/docs rationalization plan

## [1.5.1] - 2026-05-05

### Bug fixes

- replace pip install uv with astral-sh/setup-uv
- remove dead st-config.toml fallback from ci-security.yml

### Documentation

- add reusable workflows nav section to mkdocs config
- add reusable workflows overview page
- add ci-security workflow reference page
- add ci-quality workflow reference page
- add ci-audit workflow reference page
- add ci-test workflow reference page
- add ci-release workflow reference page
- update home page for v1.5 reusable workflow redesign
- update getting-started for v1.5 reusable workflow consumption
- update CI gates section for v1.5 reusable workflows
- sweep action reference pages for v1.5 accuracy

### Features

- add p/ci base ruleset and auto-detect p/dockerfile, p/github-actions

## [1.5.0] - 2026-05-04

### Features

- add five reusable CI workflows for canonical check names

## [1.4.8] - 2026-05-03

### Bug fixes

- skip language ruleset when not found in registry (#303) (#304)

### Documentation

- remove stale include directives and update docs/repository-standards.md references

## [1.4.7] - 2026-05-01

### Refactoring

- replace pip install with uv tool install and remove guard patterns
- remove runtime tool installs now that dev-base image provides them

## [1.4.4] - 2026-04-29

### Bug fixes

- self-install standard-tooling when not on PATH

## [1.4.3] - 2026-04-29

### Refactoring

- slim to PR-only checks, remove repo-profile and markdown validation

## [1.4.2] - 2026-04-29

### Bug fixes

- install standard-tooling in standards-compliance job (#255)
- add standard-tooling install to local ci.yml standards job (#255)

### Documentation

- comprehensive documentation review for consistency after v1.4.x changes

## [1.4.1] - 2026-04-28

### Features

- add CI check to reject auto-close linkage keywords in PR bodies

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
