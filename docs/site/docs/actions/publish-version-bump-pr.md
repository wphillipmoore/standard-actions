# publish/version-bump-pr

Computes the next patch version, creates a branch from develop that merges main,
updates the version file(s) via regex replacement, and opens a PR. Skips if
develop already has the expected next version.

The PR is **not auto-merged** — org-wide auto-merge is disabled. Callers
consume the `pr-url` output and drive the merge themselves (for example,
via `st-merge-when-green` from a release skill).

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@v1.5
  with:
    current-version: "1.2.3"
    version-file: VERSION
    version-regex: "^(\\d+\\.\\d+\\.)\\d+$"
    version-replacement: "\\g<1>{version}"
    develop-version-command: "cat"
    app-token: ${{ steps.app-token.outputs.token }}
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `current-version` | **Yes** | — | The version that was just published (e.g. `1.2.3`). |
| `version-file` | **Yes** | — | Path to the file containing the version string. |
| `version-regex` | **Yes** | — | Python regex to match the version line. Use capture groups for parts to preserve. |
| `version-replacement` | **Yes** | — | Python replacement string. Use `{version}` as a placeholder for the computed next version. |
| `develop-version-command` | **Yes** | — | Shell command to extract the version from the version file on develop. Receives file content on stdin. |
| `app-token` | **Yes** | — | GitHub App token for PR creation. Must be passed from the caller because composite actions cannot access secrets directly. |
| `version-regex-multiline` | No | `false` | Set to `true` to pass `re.MULTILINE` to the regex substitution. |
| `post-bump-command` | No | `""` | Shell command to run after version file edit and before commit (e.g. `uv lock --upgrade && uv export ...`). |
| `tracking-issue` | No | `""` | Issue number for the release tracking issue (e.g. `42`). If omitted, the action searches for an open issue titled `release: <current-version>`. |
| `extra-files` | No | `""` | Space-separated list of additional files to `git add` before committing. |
| `pr-body-extra` | No | `""` | Additional text appended to the PR body. |

## Outputs

| Name | Description |
| ------ | ------------- |
| `next-version` | The computed next patch version. |
| `pr-url` | URL of the created PR (empty if bump was not needed). |
| `bump-needed` | `true` if a bump PR was created, `false` if skipped. |

## Permissions

- `contents: write` (required for branch creation and pushing)

!!! note "App token required"
    The `app-token` input must be a GitHub App installation token (not the
    default `GITHUB_TOKEN`). This is necessary because PRs created by
    `GITHUB_TOKEN` do not trigger CI workflows.

## Behavior

1. **Compute next version** — Increments the patch component of
   `current-version` (e.g. `1.2.3` becomes `1.2.4`).
2. **Check develop** — Fetches `origin/develop` and extracts the current version
   using `develop-version-command`. If it already matches the next version,
   skips all remaining steps.
3. **Create bump branch** — Creates `chore/bump-version-<next>` from
   `origin/develop` and merges `origin/main` to pick up release artifacts.
4. **Update version file** — Uses Python regex substitution to replace the
   version string in the specified file.
5. **Post-bump command** — Optionally runs a command (e.g. lock file refresh).
6. **Commit and push** — Commits the version file (and any extra files) with
   message `chore: bump version to <next>`.
7. **Resolve tracking issue** — If `tracking-issue` is provided, uses that issue
   number. Otherwise, searches for an open issue titled
   `release: <current-version>`. If found, a `Ref #<number>` linkage line is
   added to the PR body. Diagnostic output is logged in either case.
8. **Create PR** — Opens a PR targeting `develop` and emits its URL as the
   `pr-url` output. Does not attempt to merge — callers drive the merge
   once CI is green.

## Examples

### Simple VERSION file bump

```yaml
- uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@v1.5
  with:
    current-version: ${{ steps.release.outputs.version }}
    version-file: VERSION
    version-regex: "^(\\d+\\.\\d+\\.)\\d+$"
    version-replacement: "\\g<1>{version}"
    develop-version-command: "cat"
    app-token: ${{ steps.app-token.outputs.token }}
```

### Python project with lock file refresh

```yaml
- uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@v1.5
  with:
    current-version: "1.0.0"
    version-file: pyproject.toml
    version-regex: '(version\s*=\s*")[\d.]+(")'
    version-replacement: '\g<1>{version}\2'
    develop-version-command: "grep -oP 'version\\s*=\\s*\"\\K[^\"]+'"
    post-bump-command: "uv lock --upgrade && uv export --no-hashes -o requirements.txt"
    extra-files: "uv.lock requirements.txt"
    app-token: ${{ steps.app-token.outputs.token }}
```

## GitHub configuration

- **GitHub App** — A GitHub App installation token is required for the
  `app-token` input. The app must have permissions to create branches, push
  commits, and create/merge pull requests.
- **Merge policy** — The PR is not auto-merged. The release workflow agent
  drives the merge via `st-merge-when-green` after CI passes.
- **Branch protection** — The `develop` branch must allow PR merges from the
  GitHub App.
