# publish/version-bump-pr

Computes the next patch version, creates a branch from develop that merges main,
updates the version file(s) via `vrg-version bump`, and opens a PR. Fails if
develop already has the expected next version — the upstream version-divergence
CI gate should prevent this; this check is its hard backstop.

The tracking issue is resolved deterministically from the merge commit on main
via `vrg-resolve-tracking-issue`. If the tool cannot find the tracking issue,
the action fails — no PR is created without issue linkage.

The PR is **not auto-merged** — org-wide auto-merge is disabled. Callers
consume the `pr-url` output and drive the merge themselves (for example,
via `vrg-merge-when-green` from a release skill).

## Usage

```yaml
- uses: vergil-project/vergil-actions/actions/cd/release/version-bump-pr@v2.0
  with:
    current-version: "1.2.3"
    app-token: ${{ steps.app-token.outputs.token }}
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `current-version` | **Yes** | — | The version that was just published (e.g. `1.2.3`). |
| `app-token` | **Yes** | — | GitHub App token for PR creation. Must be passed from the caller because composite actions cannot access secrets directly. |
| `post-bump-command` | No | `""` | Shell command to run after `vrg-version bump` and before commit (e.g. `uv lock --upgrade`). |
| `extra-files` | No | `""` | Space-separated list of additional files to `git add` before committing. |
| `pr-body-extra` | No | `""` | Additional text appended to the PR body. |

## Outputs

| Name | Description |
| ------ | ------------- |
| `next-version` | The computed next patch version. |
| `pr-url` | URL of the created PR. |

## Permissions

- `contents: write` (required for branch creation and pushing)

!!! note "App token required"
    The `app-token` input must be a GitHub App installation token (not the
    default `GITHUB_TOKEN`). This is necessary because PRs created by
    `GITHUB_TOKEN` do not trigger CI workflows.

## Behavior

1. **Compute next version** — Increments the patch component of
   `current-version` (e.g. `1.2.3` becomes `1.2.4`).
2. **Assert develop version** — Fetches `origin/develop` and extracts the
   current version via `vrg-version show`. If it already matches the next
   version, the action **fails** with a diagnostic error. This is a backstop
   for the CI version-divergence gate — if it fires, something has gone wrong
   and requires human investigation.
3. **Create bump branch** — Creates `release/bump-version-<next>` from
   `origin/develop` and merges `origin/main` to pick up release artifacts.
4. **Bump version** — Runs `vrg-version bump` to update version files.
5. **Post-bump command** — Optionally runs a command (e.g. lock file refresh).
6. **Commit and push** — Commits the version file (and any extra files) with
   message `chore: bump version to <next>`.
7. **Resolve tracking issue** — Calls `vrg-resolve-tracking-issue` to
   deterministically extract the release tracking issue number from the merge
   commit on main. The tool reads the merge commit message, extracts the PR
   number, reads the PR body, and extracts the `Ref #N` linkage. If the tool
   fails, the action fails — no PR is created without issue linkage.
8. **Create PR** — Opens a PR targeting `develop` with `Ref #<issue>` linkage
   in the body, and emits its URL as the `pr-url` output. Does not attempt to
   merge — callers drive the merge once CI is green.

## Examples

### Minimal

```yaml
- uses: vergil-project/vergil-actions/actions/cd/release/version-bump-pr@v2.0
  with:
    current-version: ${{ steps.release.outputs.version }}
    app-token: ${{ steps.app-token.outputs.token }}
```

### Python project with lock file refresh

```yaml
- uses: vergil-project/vergil-actions/actions/cd/release/version-bump-pr@v2.0
  with:
    current-version: "1.0.0"
    post-bump-command: "uv lock --upgrade && uv export --no-hashes -o requirements.txt"
    extra-files: "uv.lock requirements.txt"
    app-token: ${{ steps.app-token.outputs.token }}
```

## GitHub configuration

- **GitHub App** — A GitHub App installation token is required for the
  `app-token` input. The app must have permissions to create branches, push
  commits, and create/merge pull requests.
- **Merge policy** — The PR is not auto-merged. The release workflow agent
  drives the merge via `vrg-merge-when-green` after CI passes.
- **Branch protection** — The `develop` branch must allow PR merges from the
  GitHub App.
