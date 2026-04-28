# standards-compliance

Validates repository standards: markdown formatting, PR issue linkage,
auto-close keyword rejection, and repository profile.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/standards-compliance@v1.4
```

## Inputs

None. The action has no configurable inputs.

## Permissions

- `contents: read` (default for `github.token`)

## Behavior

The action delegates to standard-tooling CLI validators that must be on PATH.
This is satisfied either by the dev container image (non-Python consumers) or
by the consumer's own `uv sync --group dev` (Python consumers).

1. **Verify standard-tooling is installed** — Checks that `st-repo-profile` is
   available on PATH. Fails with a diagnostic message if not found.
2. **Validate repository profile** — Runs `st-repo-profile` to check required
   repository metadata.
3. **Validate markdown standards** — Runs `st-markdown-standards` to lint
   markdown files.
4. **Validate PR issue linkage** — On pull requests, runs `st-pr-issue-linkage`
   to verify the PR body references a GitHub issue.
5. **Reject auto-close linkage keywords** — On pull requests, inspects the PR
   body for `Fixes`, `Closes`, or `Resolves` keywords targeting an issue
   reference. These keywords are rejected because auto-closing bypasses the
   `st-finalize-repo` workflow. Use `Ref #N` instead.

## Examples

### Basic usage

```yaml
- uses: actions/checkout@v6
  with:
    fetch-depth: 0
- uses: wphillipmoore/standard-actions/actions/standards-compliance@v1.4
```

## GitHub configuration

- **Repository profile** — The repo must contain the files checked by
  `st-repo-profile` (typically `README.md`, `LICENSE`, `VERSION`, and standard
  documentation files).
- **Branch protection** — Recommended: require this check to pass on `develop`
  and `main` branches.
