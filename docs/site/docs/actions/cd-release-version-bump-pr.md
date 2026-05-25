# publish/version-bump-pr

!!! warning "Deprecated"
    This action is no longer invoked by the CD release pipeline. The release
    orchestrator (`vrg-release`) now handles back-merge and version bump
    directly via its `back-merge-bump` phase. See
    [vergil-tooling#1069](https://github.com/vergil-project/vergil-tooling/issues/1069).

Computes the next patch version, creates a branch from develop that merges main,
updates the version file(s) via `vrg-version bump`, and opens a PR. Fails if
develop already has the expected next version — the upstream version-divergence
CI gate should prevent this; this check is its hard backstop.

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `current-version` | **Yes** | — | The version that was just published (e.g. `1.2.3`). |
| `app-token` | **Yes** | — | GitHub App token for PR creation. |
| `post-bump-command` | No | `""` | Shell command to run after `vrg-version bump` and before commit. |
| `extra-files` | No | `""` | Space-separated list of additional files to `git add` before committing. |
| `pr-body-extra` | No | `""` | Additional text appended to the PR body. |

## Outputs

| Name | Description |
| ------ | ------------- |
| `next-version` | The computed next patch version. |
| `pr-url` | URL of the created PR. |
