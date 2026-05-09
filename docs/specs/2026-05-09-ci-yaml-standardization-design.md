# CI YAML Standardization Design

**Issue:** [#387 — chore: audit and standardize CI YAML files across the fleet](https://github.com/wphillipmoore/standard-actions/issues/387)

**Date:** 2026-05-09

**Status:** Draft

## Problem

The fleet's `ci.yml` files have diverged in format, organization, and
commenting style. Job ordering, comment conventions, `workflow_call` input
naming, input types, and yamllint pragma usage vary from repo to repo.
Structurally equivalent configurations look different depending on which repo
you're reading, making it harder to maintain consistency, spot drift, and
onboard new repos.

## Fleet (In Scope)

All repositories with a non-empty `standard-tooling.toml`, excluding archived
repos, standards-and-conventions, and the mnemosys family:

| # | Repo                         | Language      | Integration Tests |
|---|------------------------------|---------------|-------------------|
| 1 | standard-actions             | shell         | no                |
| 2 | standard-tooling             | python        | no                |
| 3 | standard-tooling-docker      | shell         | no                |
| 4 | standard-tooling-plugin      | claude-plugin | no                |
| 5 | mq-rest-admin-python         | python        | yes               |
| 6 | mq-rest-admin-go             | go            | yes               |
| 7 | mq-rest-admin-ruby           | ruby          | yes               |
| 8 | mq-rest-admin-java           | java          | yes               |
| 9 | mq-rest-admin-rust           | rust          | yes               |
| 10 | mq-rest-admin-common        | shell         | no                |
| 11 | mq-rest-admin-dev-environment | shell        | no                |
| 12 | ai-research-methodology     | python        | no                |

## Out of Scope

- Integration test jobs — left bespoke per repo, to be tackled as a separate
  issue.
- `cd.yml` content and reusable workflow internals — being designed in a
  parallel brainstorming session. The README will include placeholder sections
  for these. The formatting rules apply to them, but their specific structure
  will be defined separately and merged into the README later.

## Architecture

The workflow architecture is flat. standard-actions is the sole provider of
reusable workflows. Every other repo is a consumer. Consumers never provide
reusable workflows to other repos. There is no chaining or nesting.

```text
standard-actions (provider)
  ci-quality.yml, ci-security.yml, ci-test.yml, ci-audit.yml, ci-release.yml
    ↓ consumed by
  every other repo's ci.yml (consumer only — never a provider)
```

## Convention

### Formatting Rules

These rules apply to all workflow YAML files across the fleet — `ci.yml`,
`cd.yml` (when it exists), and the reusable workflow files in
standard-actions.

#### File-level structure (top to bottom)

1. Reference comment (URL to the README — see below)
2. `name:`
3. `on:` (trigger configuration)
4. `permissions:` (if needed at workflow level)
5. `concurrency:` (if needed)
6. `jobs:` — entries in **alphabetical order** by job key

#### Job ordering

Alphabetical by job key. Always. No exceptions. This is deterministic and
removes all judgment calls about "logical grouping." Since GitHub Actions runs
jobs in parallel by default (unless constrained by `needs:`), the order in the
file is purely organizational.

#### Comments

- No section banners or decorative separators.
- No redundant labels (a comment that restates the job key below it is
  pointless).
- Comments only when the YAML itself does not convey the intent — e.g.,
  explaining a workaround, a non-obvious constraint, or a known issue.
- No `# yamllint disable-line` pragmas. The shared yamllint config
  (`standard-tooling/configs/yamllint.yaml`) already exempts workflow files
  from line-length checks. If any other yamllint rule triggers, fix the YAML
  rather than suppressing the warning.

#### Whitespace

- One blank line between top-level keys (`on:`, `permissions:`,
  `concurrency:`, `jobs:`).
- One blank line between jobs within the `jobs:` block.
- No trailing blank lines at end of file.

### Standardized `workflow_call` Inputs

#### Toggle inputs

All boolean toggle inputs use `type: boolean` (not `type: string`).
Standard toggle inputs and their names:

- `run-security` — `type: boolean`, `default: true`
- `run-release` — `type: boolean`, `default: true`

#### Version matrix input

The input for language version matrices is always named `versions`
(not language-prefixed like `go-versions` or `ruby-versions`). It uses
`type: string` since GitHub Actions does not support array-typed inputs.

Repos that do not have a version matrix (shell/no-language repos) omit this
input.

### Bespoke Jobs

Some repos have jobs that do not come from standard-actions' reusable
workflows:

- **standard-tooling-docker** — `hadolint` (Dockerfile linting)
- **standard-tooling-plugin** — `mkdocs-build` (docs build check)
- **mq-rest-admin-rust** — custom `test` job with coverage thresholds

Bespoke jobs follow the same formatting rules as standard jobs. They sort
alphabetically alongside everything else. If a bespoke job replaces a standard
reusable workflow (e.g., Rust's custom `test` replaces the reusable
`ci-test.yml`), it keeps the same job key so it sorts into the expected
position.

### Reference Comment

Every consuming repo's workflow files include a single comment on line 1
pointing to the convention doc:

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
name: CI
```

Rules:

- Line 1, always — before `name:`.
- Just the raw URL, no surrounding prose.
- Points to the `develop` branch.
- standard-actions' own workflow files skip this since the README is co-located
  in the same directory.

### standard-actions' Own CI

standard-actions uses local `./` paths for self-testing rather than remote
references. The same formatting rules apply: alphabetical job ordering, no
redundant comments, standardized inputs. The reference comment is omitted
because the README is in the same directory.

## Deliverable: `.github/workflows/README.md`

A single canonical document in standard-actions at
`.github/workflows/README.md`. This file serves as both the convention
specification and the reference implementation.

### README Structure

1. **Header** — what this document is and who it's for.
2. **Formatting rules** — the universal rules defined above.
3. **Reference comment convention** — the URL comment that goes at the top of
   every consuming repo's workflow files.
4. **Examples by archetype** — complete, copy-pasteable YAML blocks showing the
   canonical form for each type of consumer:
   - **standard-actions `ci.yml`** — self-referencing with local `./` paths.
   - **Shell/no-language consumer** — simplest case (pattern for
     mq-rest-admin-common, mq-rest-admin-dev-environment).
   - **Python consumer without integration tests** — pattern for
     standard-tooling, ai-research-methodology.
   - **Python consumer with integration tests** — pattern for
     mq-rest-admin-python (integration block shown as a placeholder noting it
     is bespoke).
   - **Go consumer** — pattern for mq-rest-admin-go.
   - **Ruby consumer** — pattern for mq-rest-admin-ruby.
   - **Java consumer** — pattern for mq-rest-admin-java.
   - **Rust consumer** — pattern for mq-rest-admin-rust.
   - **Plugin consumer** — pattern for standard-tooling-plugin (includes
     bespoke mkdocs-build job).
   - **Docker consumer** — pattern for standard-tooling-docker (includes
     bespoke hadolint job).
   - **`cd.yml` examples** — placeholder section, to be filled after the
     parallel rename brainstorm is complete.
   - **Reusable workflow files** — placeholder section for the `ci-*.yml`
     files in standard-actions, to be filled after the parallel brainstorm.

Each example is a complete YAML block that can be copied directly into a repo
and customized only where noted (e.g., language, versions).

## Changes Required Per Repo

### standard-actions

- Create `.github/workflows/README.md` with the convention and examples.
- Reorder jobs in `ci.yml` alphabetically.
- Remove any redundant comments.

### standard-tooling

- Add reference comment.
- Remove section banner comments.
- Already uses `type: boolean` and correct input names — no input changes.
- Reorder jobs alphabetically (currently: quality, test, audit, security,
  release → alphabetical: audit, quality, release, security, test).

### standard-tooling-docker

- Add reference comment.
- Remove section banner comments.
- Reorder jobs alphabetically (currently: quality, hadolint, security,
  release → alphabetical: hadolint, quality, release, security).

### standard-tooling-plugin

- Add reference comment.
- Remove section banner comments.
- Reorder jobs alphabetically (currently: quality, mkdocs-build, security,
  release → alphabetical: mkdocs-build, quality, release, security).

### mq-rest-admin-python

- Add reference comment.
- Remove section banner comments.
- Reorder jobs alphabetically (currently: quality, test, audit,
  integration-tests, security, release → alphabetical: audit,
  integration-tests, quality, release, security, test).

### mq-rest-admin-go

- Add reference comment.
- Rename `go-versions` input to `versions`.
- Change `run-security` and `run-release` from `type: string` to
  `type: boolean`.
- Reorder jobs alphabetically (currently: quality, test, audit,
  integration-tests, security, release → alphabetical: audit,
  integration-tests, quality, release, security, test).

### mq-rest-admin-ruby

- Add reference comment.
- Rename `ruby-versions` input to `versions`.
- Change `run-security` and `run-release` from `type: string` to
  `type: boolean`.
- Reorder jobs alphabetically (already close but needs verification).

### mq-rest-admin-java

- Add reference comment.
- Rename `java-versions` input to `versions`.
- Remove all `# yamllint disable-line` pragmas.
- Reorder jobs alphabetically (currently: quality, security, release, test,
  audit, integration-tests → alphabetical: audit, integration-tests, quality,
  release, security, test).

### mq-rest-admin-rust

- Add reference comment.
- Rename `rust-versions` input to `versions`.
- Change `run-security` and `run-release` from `type: string` to
  `type: boolean`.
- Reorder jobs alphabetically (currently: quality, test, audit,
  integration-tests, security, release → alphabetical: audit,
  integration-tests, quality, release, security, test).

### mq-rest-admin-common

- Add reference comment.
- Remove any section banner comments (if present — currently has none).
- Reorder jobs alphabetically (currently: quality, security, release →
  already alphabetical? No: alphabetical is quality, release, security).

### mq-rest-admin-dev-environment

- Add reference comment.
- Remove section banner comments.
- Reorder jobs alphabetically (currently: quality, security, release →
  alphabetical: quality, release, security).

### ai-research-methodology

- Add reference comment.
- Remove section banner comments.
- Reorder jobs alphabetically (currently: quality, test, audit, security,
  release → alphabetical: audit, quality, release, security, test).

## Coordination

This spec covers the `ci.yml` formatting convention. A parallel brainstorming
session is designing the `publish` → `cd.yml` rename. The two specs will be
merged in a subsequent brainstorming session to produce a single coordinated
rollout plan covering both changes.
