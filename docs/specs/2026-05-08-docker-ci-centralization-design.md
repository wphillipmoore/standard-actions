# Docker CI Centralization Design

**Issue:** [#378 — ci: factor out Docker-specific CI actions as reusable workflows](https://github.com/wphillipmoore/standard-actions/issues/378)

**Date:** 2026-05-08

**Status:** Design complete — original issue scope revised

## Context

Issue #378 proposed creating reusable Docker CI workflows and composite
actions in standard-actions to centralize hadolint and other
Docker-specific checks. Two repositories were identified as consumers:
standard-tooling-docker (builds dev container images for the fleet) and
mq-rest-admin-dev-environment (runs vendor-provided IBM MQ images for
integration tests).

## Design Outcome

Through analysis, the original goal — new composite actions or reusable
workflows in standard-actions — turned out not to be needed. The work
decomposes into smaller, better-targeted changes:

### 1. st-validate already integrates hadolint (no change needed)

`validate_common.py` in standard-tooling already auto-detects Dockerfile
files and runs hadolint on them. This means any repo running `st-validate`
(via `ci-quality.yml`) gets hadolint for free when Dockerfiles are present.

No centralized hadolint config file is needed. Hadolint's out-of-the-box
defaults are the right fleet-wide defaults. Repos needing exceptions (such
as standard-tooling-docker's DL3008/DL3028/DL3059 ignores for dev images)
provide their own `.hadolint.yaml` at the repo root, which hadolint
auto-discovers natively.

This differs from markdownlint and yamllint, where fleet-wide conventions
(line length, document-start rules) diverge from tool defaults and
therefore require centralized config files.

**Action:** Verify the existing hadolint integration in `validate_common.py`
works correctly. No code changes expected.

### 2. Fix standard-tooling-docker's bespoke hadolint jobs

The hadolint jobs in standard-tooling-docker currently run on bare
`ubuntu-latest` and download the hadolint binary via curl. This bypasses
the managed tooling in the dev-base container image.

**Changes to `ci.yml` hadolint job:**
- Run inside `ghcr.io/wphillipmoore/dev-base:latest` container
- Remove the curl/download step
- Keep `docker/generate.sh` and `hadolint docker/*/Dockerfile` as-is

**Changes to `docker-publish.yml` hadolint job:**
- Same: switch to dev-base container, remove the download step
- Keep generate + lint steps unchanged

The `.hadolint.yaml` remains in the repo — its ignores are specific to
how this repo builds dev container images, not fleet-wide policy.

The generate.sh template system (which expands `# @include` directives
in Dockerfile.template files) is out of scope for this work. It functions
correctly and any refactoring would be a separate effort.

### 3. Close issue #378

The original goal (reusable Docker CI actions in standard-actions) is not
needed. Hadolint execution is already centralized in st-validate. The
remaining work is scoped to standard-tooling-docker's CI configuration.

Close #378 with a comment explaining the outcome.

## Out of Scope

- **mq-rest-admin-dev-environment** — Uses vendor-provided IBM MQ images
  as black-box infrastructure for integration tests. No custom Dockerfiles,
  nothing to lint or build. Not a consumer of Docker CI actions.

- **docker/generate.sh refactoring** — The template expansion system in
  standard-tooling-docker works correctly. Rethinking it is a separate
  effort.

- **Centralized hadolint config** — Not needed. Hadolint defaults are
  appropriate fleet-wide; repo-specific overrides via `.hadolint.yaml`
  handle exceptions.

## Affected Repositories

| Repository | Change |
|---|---|
| standard-tooling | Verify existing hadolint integration in st-validate |
| standard-tooling-docker | Fix CI jobs to use dev-base container |
| standard-actions | Close issue #378 |
