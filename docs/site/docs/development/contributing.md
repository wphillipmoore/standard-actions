# Contributing

## Adding a new action

1. Create a directory under `actions/` following the existing naming pattern:
   `actions/<category>/<action-name>/action.yml`.
2. Define the action as a **composite action** — no custom JavaScript or Docker
   actions.
3. Include clear `name`, `description`, `inputs`, and `outputs` in `action.yml`.
4. Add supporting scripts under `actions/<action-name>/scripts/` if needed.
5. Add the action to the CI workflow (`.github/workflows/ci.yml`) using a local
   path reference (`./actions/<path>`).
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
- uses: ./actions/standards-compliance   # Not the remote reference
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

- `--linkage`: `Fixes|Closes|Resolves|Ref` (default: `Fixes`)
- `--title`: PR title (default: most recent commit subject)
- `--notes`: Additional notes
- `--dry-run`: Print without executing
