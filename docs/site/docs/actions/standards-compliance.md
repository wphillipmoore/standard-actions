# standards-compliance

Validates repository standards: markdown formatting, commit messages, PR issue
linkage, and repository profile.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/standards-compliance@develop
  with:
    commit-cutoff-sha: ""
    skip-sync-check: "false"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `commit-cutoff-sha` | No | `""` | Skip commits at or before this SHA. Repos that adopted conventional commits after their initial history pass their cutoff here. |
| `skip-sync-check` | No | `false` | Skip the shared tooling staleness check. Set to `true` for repositories that ARE the canonical source for synced scripts (e.g. standard-tooling). |

## Permissions

- `contents: read` (default for `github.token`)

## Behavior

1. **Set up Node.js** — Installs Node.js 20 for markdownlint.
2. **Install markdownlint-cli** — Global npm install.
3. **Fetch base branch** — On pull requests, fetches the base branch for commit
   range linting.
4. **Validate repository profile** — Runs `repo-profile.sh` to check required
   repository metadata files.
5. **Validate markdown standards** — Runs `markdown-standards.sh` with
   markdownlint against the repository.
6. **Validate commit messages** — On pull requests, runs `commit-messages.sh` to
   verify conventional commit format for all commits in the PR range.
7. **Validate PR issue linkage** — On pull requests, runs `pr-issue-linkage.sh`
   to verify the PR body references a GitHub issue.
8. **Validate shared tooling** — On PRs targeting `develop`, checks whether
   shared scripts are up to date with the canonical versions in the
   `standard-tooling` package.

## Examples

### Basic usage

```yaml
- uses: actions/checkout@v6
  with:
    fetch-depth: 0
- uses: wphillipmoore/standard-actions/actions/standards-compliance@develop
```

### With commit cutoff for legacy repos

```yaml
- uses: wphillipmoore/standard-actions/actions/standards-compliance@develop
  with:
    commit-cutoff-sha: "abc123def456"
```

### Skip sync check for canonical tooling repo

```yaml
- uses: wphillipmoore/standard-actions/actions/standards-compliance@develop
  with:
    skip-sync-check: "true"
```

## GitHub configuration

- **Repository profile** — The repo must contain the files checked by
  `repo-profile.sh` (typically `README.md`, `LICENSE`, `VERSION`, and standard
  documentation files).
- **Branch protection** — Recommended: require this check to pass on `develop`
  and `main` branches.
