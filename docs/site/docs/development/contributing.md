# Contributing

## Adding a new action

1. Create a directory under `actions/` following the namespace convention:
   `actions/{phase}/{domain}/{action}/action.yml`. The phase (`ci`, `cd`)
   and domain (`security`, `release`, etc.) match the workflow filename
   that will consume the action. Use `shared/` for cross-phase actions
   and `local/` for actions specific to this repo.
2. Define the action as a **composite action** — no custom JavaScript or Docker
   actions.
3. Include clear `name`, `description`, `inputs`, and `outputs` in `action.yml`.
4. Add supporting scripts under the action directory's `scripts/` subdirectory
   if needed.
5. Add the action to the appropriate workflow using a local path reference
   (`./actions/{phase}/{domain}/{action}`).
6. Add a documentation page under `docs/site/docs/actions/` and update the nav
   in `docs/site/mkdocs.yml`.

## Composite action design rules

- **Shell steps only** — Use `shell: bash` for all `run` steps.
- **No secrets access** — Composite actions cannot access secrets directly.
  Callers must pass secrets as inputs.
- **Idempotent when possible** — Actions should be safe to re-run (e.g.,
  `publish/tag-and-release` skips if the tag exists).
- **Environment variables for sensitive data** — Use `env` blocks rather than
  inline interpolation for values that might contain special characters.

## Testing via self-referencing CI

This repository tests its own actions by using local path references in the CI
workflow:

```yaml
- uses: ./actions/ci/security/standards-compliance   # Not the remote reference
```

When you modify an action, the PR's CI run uses your modified version. This
provides integration testing without a separate test repository.

## Branching workflow

- **Protected branches**: `main` and `develop` — no direct commits.
- **Branch naming**: `feature/*`, `bugfix/*`, or `hotfix/*` only.
- Feature and bugfix PRs target `develop` with squash merge.
- Release PRs target `main` with regular merge.

## Committing

Always use the commit script:

```bash
st-commit \
  --type feat \
  --scope ci \
  --message "add new validation check" \
  --agent claude
```

Required flags:

- `--type`: `feat|fix|docs|style|refactor|test|chore|ci|build`
- `--message`: Commit description
- `--agent`: `claude` or `codex`

Optional flags:

- `--scope`: Conventional commit scope
- `--body`: Detailed commit body

## Submitting PRs

Always use the PR script:

```bash
st-submit-pr \
  --issue 42 \
  --summary "Add new validation check"
```

Required flags:

- `--issue`: GitHub issue number
- `--summary`: One-line PR summary

Optional flags:

- `--linkage`: `Ref` (default). `Fixes`, `Closes`, and `Resolves` are rejected
  by the `standards-compliance` CI gate.
- `--title`: PR title (default: most recent commit subject)
- `--notes`: Additional notes
- `--dry-run`: Print without executing
