# Standard Actions Standards and Conventions

This repository follows the canonical standards in the Standards and
Conventions repository:
https://github.com/wphillipmoore/standards-and-conventions/tree/develop

## Table of Contents
- [Canonical references](#canonical-references)
- [Project-specific overlay](#project-specific-overlay)

## Canonical references
- Code management overview: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/overview.md
- Pull request workflow: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/pull-request-workflow.md
- Commit messages and authorship: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/commit-messages-and-authorship.md
- Library branching and release model: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/library-branching-and-release.md
- Library versioning scheme: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/library-versioning-scheme.md
- Release and versioning policy: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/release-versioning.md
- Shared actions library: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/code-management/shared-actions-library.md
- Markdown standards: https://github.com/wphillipmoore/standards-and-conventions/blob/develop/docs/foundation/markdown-standards.md
- Development overview: docs/development/overview.md

## Project-specific overlay
- Repository profile:
  - repository_type: library
  - versioning_scheme: library
  - branching_model: library-release
  - release_model: artifact-publishing
  - supported_release_lines: 0.x (pre-release)
- AI co-authors:
  - Co-Authored-By: wphillipmoore-codex <255923655+wphillipmoore-codex@users.noreply.github.com>
  - Co-Authored-By: wphillipmoore-claude <255925739+wphillipmoore-claude@users.noreply.github.com>
- Local deviations:
  - Releases are distributed via GitHub Actions tags rather than a package registry.
