# Standard Actions Standards and Conventions

This repository follows the canonical standards in the Standards and
Conventions repository:
https://github.com/wphillipmoore/standards-and-conventions/tree/develop

## Table of Contents
- [Canonical references](#canonical-references)
  - [Core references (always required)](#core-references-always-required)
  - [Repository-type references (required for the declared type)](#repository-type-references-required-for-the-declared-type)
  - [Additional required references](#additional-required-references)
- [Project-specific overlay](#project-specific-overlay)
  - [Repository profile](#repository-profile)
  - [AI co-authors](#ai-co-authors)
  - [Local references](#local-references)
  - [Local deviations](#local-deviations)

## Canonical references

### Core references (always required)
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/foundation/markdown-standards.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/repository-types-and-attributes.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/commit-messages-and-authorship.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/github-issues.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/pull-request-workflow.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/source-control-guidelines.md

### Repository-type references (required for the declared type)
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/library-branching-and-release.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/library-versioning-scheme.md

### Additional required references
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/overview.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/release-versioning.md
- https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/shared-actions-library.md

## Project-specific overlay

### Repository profile

- repository_type: library
- versioning_scheme: library
- branching_model: library-release
- release_model: artifact-publishing
- supported_release_lines: 0.x (pre-release)

### AI co-authors

- Co-Authored-By: wphillipmoore-codex <255923655+wphillipmoore-codex@users.noreply.github.com>
- Co-Authored-By: wphillipmoore-claude <255925739+wphillipmoore-claude@users.noreply.github.com>

### Local references

- docs/development/overview.md

### Local deviations

- Releases are distributed via GitHub Actions tags rather than a package registry.
