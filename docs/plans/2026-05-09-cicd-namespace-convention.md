# CI/CD Namespace Convention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename shared workflow files from `publish-*` to `cd-*` and `ci-release` to `ci-version-bump`, aligning the naming convention to the CI/CD lifecycle across the entire fleet.

**Architecture:** Three-phase rollout: (1) update standard-tooling's check name registry and release, (2) rename workflows in standard-actions and release v1.5.x, (3) sweep all 12 consumer repos with a scripted rollout. Standard-tooling must release first because its ruleset sync tool enforces check names — deploying new names before updating the registry would cause conflicts.

**Tech Stack:** GitHub Actions YAML, Python (standard-tooling), Shell (rollout script), gh CLI

---

## Phase 1: standard-tooling changes

### Task 1: Update check name registry tests

**Repo:** standard-tooling (`/Users/pmoore/dev/github/standard-tooling`)
**Files:**
- Modify: `tests/standard_tooling/test_github_config_lib.py:272-279`

- [ ] **Step 1: Update test to expect new check name**

In `tests/standard_tooling/test_github_config_lib.py`, change the two
test functions:

```python
def test_ci_gates_release_version_bump_present() -> None:
    r = desired_ci_gates_ruleset(_project(release_model="tagged-release"), _ci())
    assert "version / version-bump" in _check_names(r)


def test_ci_gates_no_release_when_none() -> None:
    r = desired_ci_gates_ruleset(_project(release_model="none"), _ci())
    assert "version / version-bump" not in _check_names(r)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- pytest tests/standard_tooling/test_github_config_lib.py::test_ci_gates_release_version_bump_present tests/standard_tooling/test_github_config_lib.py::test_ci_gates_no_release_when_none -v`

Expected: FAIL — the code still produces `release / version-bump`.

---

### Task 2: Update check name registry code

**Repo:** standard-tooling
**Files:**
- Modify: `src/standard_tooling/lib/github_config.py:283-285`

- [ ] **Step 1: Change the check name string**

In `src/standard_tooling/lib/github_config.py`, change line 285 from:

```python
    # Release check
    if project.release_model != "none":
        checks.append(_make_check("release / version-bump"))
```

to:

```python
    # Version check
    if project.release_model != "none":
        checks.append(_make_check("version / version-bump"))
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- pytest tests/standard_tooling/test_github_config_lib.py -v`

Expected: All tests PASS.

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- pytest -v`

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling
st-commit --type feat --scope github-config --message "rename release/version-bump check to version/version-bump (#383)" --agent claude
```

---

### Task 3: Rename standard-tooling workflow files

**Repo:** standard-tooling
**Files:**
- Delete: `.github/workflows/publish-release.yml`
- Delete: `.github/workflows/publish-docs.yml`
- Create: `.github/workflows/cd.yml`
- Modify: `.github/workflows/ci.yml:64-73`

- [ ] **Step 1: Create `cd.yml` merging the two publish callers**

Create `.github/workflows/cd.yml`:

```yaml
name: CD

on:
  push:
    branches: [develop, main]
  workflow_dispatch:

jobs:
  release:
    if: github.ref == 'refs/heads/main'
    uses: wphillipmoore/standard-actions/.github/workflows/cd-release.yml@v1.5
    with:
      language: python
    secrets: inherit
    permissions:
      attestations: write
      contents: write
      id-token: write
      pull-requests: write

  docs:
    uses: wphillipmoore/standard-actions/.github/workflows/cd-docs.yml@v1.5
    permissions:
      contents: write
```

- [ ] **Step 2: Delete old publish workflow files**

```bash
cd /Users/pmoore/dev/github/standard-tooling
git rm .github/workflows/publish-release.yml .github/workflows/publish-docs.yml
```

- [ ] **Step 3: Update `ci.yml` job key and uses path**

In `.github/workflows/ci.yml`, change lines 64-73 from:

```yaml
  # ---------------------------------------------------------------------------
  # Release
  # ---------------------------------------------------------------------------

  release:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-release.yml@v1.5
    with:
      language: python
      run-release: ${{ inputs.run-release != false }}
      container-tag: '3.14'
      container-suffix: python
```

to:

```yaml
  # ---------------------------------------------------------------------------
  # Version
  # ---------------------------------------------------------------------------

  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: python
      run-release: ${{ inputs.run-release != false }}
      container-tag: '3.14'
      container-suffix: python
```

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling
git add .github/workflows/cd.yml
st-commit --type feat --scope ci --message "rename publish workflows to cd convention (#383)" --agent claude
```

---

### Task 4: Release standard-tooling

**Repo:** standard-tooling

This task is manual — use the standard publish workflow or `/standard-tooling:publish` skill.

- [ ] **Step 1: Version bump and release**

Follow the standard release process to cut a new standard-tooling
version containing the check name registry update and workflow renames.

---

## Phase 2: standard-actions changes

### Task 5: Rename `ci-release.yml` to `ci-version-bump.yml`

**Repo:** standard-actions (`/Users/pmoore/dev/github/standard-actions`)
**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Delete: `.github/workflows/ci-release.yml`
- Create: `.github/workflows/ci-version-bump.yml`
- Modify: `.github/workflows/ci.yml:30-33`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git mv .github/workflows/ci-release.yml .github/workflows/ci-version-bump.yml
```

- [ ] **Step 2: Update the workflow `name:` field**

In `.github/workflows/ci-version-bump.yml`, change:

```yaml
name: CI Release
```

to:

```yaml
name: CI Version Bump
```

- [ ] **Step 3: Update `ci.yml` job key and uses path**

In `.github/workflows/ci.yml`, change:

```yaml
  release:
    uses: ./.github/workflows/ci-release.yml
    with:
      language: shell
```

to:

```yaml
  version:
    uses: ./.github/workflows/ci-version-bump.yml
    with:
      language: shell
```

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
st-commit --type feat --scope ci --message "rename ci-release.yml to ci-version-bump.yml (#383)" --agent claude
```

---

### Task 6: Rename `publish-release.yml` to `cd-release.yml`

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Delete: `.github/workflows/publish-release.yml`
- Create: `.github/workflows/cd-release.yml`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git mv .github/workflows/publish-release.yml .github/workflows/cd-release.yml
```

- [ ] **Step 2: Update the workflow `name:` field**

In `.github/workflows/cd-release.yml`, change:

```yaml
name: Publish release
```

to:

```yaml
name: CD Release
```

- [ ] **Step 3: Update the concurrency group**

In `.github/workflows/cd-release.yml`, change:

```yaml
concurrency:
  group: publish
  cancel-in-progress: false
```

to:

```yaml
concurrency:
  group: cd
  cancel-in-progress: false
```

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
st-commit --type feat --scope cd --message "rename publish-release.yml to cd-release.yml (#383)" --agent claude
```

---

### Task 7: Split `publish-docs.yml` into `cd-docs.yml`

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Delete: `.github/workflows/publish-docs.yml`
- Create: `.github/workflows/cd-docs.yml`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git mv .github/workflows/publish-docs.yml .github/workflows/cd-docs.yml
```

- [ ] **Step 2: Strip the push triggers and update name**

Replace the entire `on:` block and `name:` in `.github/workflows/cd-docs.yml`.

Change:

```yaml
name: Publish docs

on:
  push:
    branches: [develop, main]
  workflow_dispatch:
  workflow_call:
```

to:

```yaml
name: CD Docs

on:
  workflow_call:
```

- [ ] **Step 3: Update the concurrency group**

In `.github/workflows/cd-docs.yml`, change:

```yaml
concurrency:
  group: docs
  cancel-in-progress: false
```

to:

```yaml
concurrency:
  group: cd-docs
  cancel-in-progress: false
```

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
st-commit --type feat --scope cd --message "split publish-docs.yml into cd-docs.yml (workflow_call only) (#383)" --agent claude
```

---

### Task 8: Create `cd.yml` from `publish.yml`

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Delete: `.github/workflows/publish.yml`
- Create: `.github/workflows/cd.yml`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git mv .github/workflows/publish.yml .github/workflows/cd.yml
```

- [ ] **Step 2: Update the workflow header**

In `.github/workflows/cd.yml`, change:

```yaml
name: Publish release

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: publish
  cancel-in-progress: false
```

to:

```yaml
name: CD

on:
  push:
    branches: [develop, main]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: cd
  cancel-in-progress: false
```

- [ ] **Step 3: Add `if` condition to the release job**

In `.github/workflows/cd.yml`, the existing `publish` job needs a
condition so it only runs on main. Change:

```yaml
jobs:
  publish:
    name: "publish / release"
```

to:

```yaml
jobs:
  release:
    name: "cd / release"
    if: github.ref == 'refs/heads/main'
```

- [ ] **Step 4: Add the docs job**

At the end of `.github/workflows/cd.yml`, after the release job, add:

```yaml
  docs:
    uses: ./.github/workflows/cd-docs.yml
    permissions:
      contents: write
```

- [ ] **Step 5: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
st-commit --type feat --scope cd --message "rename publish.yml to cd.yml umbrella with docs job (#383)" --agent claude
```

---

### Task 9: Update documentation

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Modify: `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`
- Modify: `docs/site/docs/configuration.md` (if it references old filenames)
- Modify: Any other docs referencing `publish-release.yml`, `publish-docs.yml`,
  `ci-release.yml`, or `publish.yml`

- [ ] **Step 1: Find all documentation references to old filenames**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
grep -rn "publish-release\.yml\|publish-docs\.yml\|ci-release\.yml\|publish\.yml" docs/ --include="*.md"
```

- [ ] **Step 2: Update each reference**

For each file found in step 1, update old filenames to their new names:
- `ci-release.yml` → `ci-version-bump.yml`
- `publish-release.yml` → `cd-release.yml`
- `publish-docs.yml` → `cd-docs.yml`
- `publish.yml` → `cd.yml`

Also update any references to old check names:
- `release / version-bump` → `version / version-bump`
- `publish / release` → `cd / release`
- `publish / docs` → `cd / docs`

- [ ] **Step 3: Add superseded note to rationalization spec**

At the top of `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`,
after the header, add:

```markdown
> **Note:** The `publish-*` naming convention in this spec has been
> superseded by the CI/CD namespace convention
> ([#383](https://github.com/wphillipmoore/standard-actions/issues/383)).
> `publish-release.yml` → `cd-release.yml`, `publish-docs.yml` → `cd-docs.yml`.
> Architectural decisions (thin callers, workflow_call interfaces) remain valid.
```

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
st-commit --type docs --scope specs --message "update documentation for CI/CD namespace convention (#383)" --agent claude
```

---

### Task 10: Validate and release standard-actions

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`

- [ ] **Step 1: Full validation**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 2: Verify final workflow layout**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
ls -1 .github/workflows/
```

Expected output:

```
cd-docs.yml
cd-release.yml
cd.yml
ci-audit.yml
ci-quality.yml
ci-security.yml
ci-test.yml
ci-version-bump.yml
ci.yml
```

- [ ] **Step 3: Push branch and create PR**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git push -u origin feature/383-cicd-namespace
```

Create PR targeting develop. After merge, follow the standard release
process to cut a v1.5.x release.

---

## Phase 3: Fleet sweep

### Task 11: Write rollout script

**Worktree:** `/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace/`
**Files:**
- Create: `scripts/fleet-cicd-rename.sh`

The script operates on a single repo at a time and is idempotent (safe
to re-run). It clones no repos — it expects them at
`/Users/pmoore/dev/github/<repo-name>`.

- [ ] **Step 1: Write the rollout script**

Create `scripts/fleet-cicd-rename.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Fleet-wide CI/CD namespace rename script.
# Usage: fleet-cicd-rename.sh <repo-name|all>

GITHUB_BASE="/Users/pmoore/dev/github"
GITHUB_ORG="wphillipmoore"
BRANCH="chore/383-cicd-namespace"
SA_TAG="v1.5"  # Update to actual release tag

REPOS=(
  standard-tooling
  standard-tooling-docker
  standard-tooling-plugin
  mq-rest-admin-python
  mq-rest-admin-go
  mq-rest-admin-ruby
  mq-rest-admin-java
  mq-rest-admin-rust
  mq-rest-admin-common
  mq-rest-admin-dev-environment
  ai-research-methodology
)

rename_repo() {
  local repo="$1"
  local repo_path="${GITHUB_BASE}/${repo}"

  if [ ! -d "$repo_path" ]; then
    echo "SKIP: $repo — directory not found at $repo_path"
    return
  fi

  echo "=== Processing $repo ==="
  cd "$repo_path"

  git checkout develop
  git pull
  git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

  local wf=".github/workflows"

  # --- CI workflow: rename release job key and uses path ---
  if [ -f "$wf/ci.yml" ]; then
    if grep -q "ci-release\.yml" "$wf/ci.yml"; then
      sed -i.bak \
        -e 's|ci-release\.yml|ci-version-bump.yml|g' \
        "$wf/ci.yml"
      rm -f "$wf/ci.yml.bak"

      # Rename job key: "  release:" -> "  version:"
      # and section comment
      sed -i.bak \
        -e 's/^  release:$/  version:/' \
        -e 's/# Release/# Version/' \
        "$wf/ci.yml"
      rm -f "$wf/ci.yml.bak"

      echo "  Updated ci.yml"
    fi
  fi

  # --- Merge publish-release.yml + publish-docs.yml into cd.yml ---
  local has_release=false
  local has_docs=false
  local release_with=""
  local docs_with=""

  if [ -f "$wf/publish-release.yml" ]; then
    has_release=true
    # Extract the 'with:' block content (lines after 'with:' until next
    # top-level key or end of file)
    release_with=$(sed -n '/^    with:/,/^    [a-z]/{ /^    with:/d; /^    [a-z]/d; p; }' "$wf/publish-release.yml" || true)
  fi

  if [ -f "$wf/publish-docs.yml" ]; then
    has_docs=true
    docs_with=$(sed -n '/^    with:/,/^    [a-z]/{ /^    with:/d; /^    [a-z]/d; p; }' "$wf/publish-docs.yml" || true)
  fi

  if $has_release || $has_docs; then
    {
      echo "name: CD"
      echo ""
      echo "on:"
      echo "  push:"
      if $has_docs; then
        echo "    branches: [develop, main]"
      else
        echo "    branches: [main]"
      fi
      echo "  workflow_dispatch:"

      if $has_release; then
        echo ""
        echo "permissions:"
        echo "  attestations: write"
        echo "  contents: write"
        echo "  id-token: write"
        echo "  pull-requests: write"
      fi

      echo ""
      echo "jobs:"

      if $has_release; then
        echo "  release:"
        if $has_docs; then
          echo "    if: github.ref == 'refs/heads/main'"
        fi
        echo "    uses: ${GITHUB_ORG}/standard-actions/.github/workflows/cd-release.yml@${SA_TAG}"
        if [ -n "$release_with" ]; then
          echo "    with:"
          echo "$release_with"
        fi
        echo "    secrets: inherit"
        if ! $has_docs; then
          echo "    permissions:"
          echo "      attestations: write"
          echo "      contents: write"
          echo "      id-token: write"
          echo "      pull-requests: write"
        fi
      fi

      if $has_docs; then
        echo ""
        echo "  docs:"
        echo "    uses: ${GITHUB_ORG}/standard-actions/.github/workflows/cd-docs.yml@${SA_TAG}"
        if [ -n "$docs_with" ]; then
          echo "    with:"
          echo "$docs_with"
        fi
        echo "    permissions:"
        echo "      contents: write"
      fi
    } > "$wf/cd.yml"

    $has_release && git rm "$wf/publish-release.yml"
    $has_docs && git rm "$wf/publish-docs.yml"
    git add "$wf/cd.yml"

    echo "  Created cd.yml, removed old publish files"
  fi

  git add -A
  if git diff --cached --quiet; then
    echo "  No changes — skipping"
    git checkout develop
    return
  fi

  st-commit --type feat --scope ci \
    --message "rename workflows to CI/CD namespace convention (#383)" \
    --agent claude

  git push -u origin "$BRANCH"

  gh pr create \
    --title "feat(ci): adopt CI/CD namespace convention (#383)" \
    --body "Rename workflow files to follow CI/CD namespace convention.

- ci-release.yml → ci-version-bump.yml (job key: release → version)
- publish-release.yml + publish-docs.yml → cd.yml umbrella
- Refs: standard-actions#383" \
    --base develop

  echo "  PR created for $repo"
}

# --- Main ---
target="${1:-}"

if [ -z "$target" ]; then
  echo "Usage: $0 <repo-name|all>"
  exit 1
fi

if [ "$target" = "all" ]; then
  for repo in "${REPOS[@]}"; do
    rename_repo "$repo"
  done
else
  rename_repo "$target"
fi
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/fleet-cicd-rename.sh
```

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
git add scripts/fleet-cicd-rename.sh
st-commit --type feat --scope scripts --message "add fleet-wide CI/CD namespace rollout script (#383)" --agent claude
```

---

### Task 12: Execute fleet sweep

- [ ] **Step 1: Verify prerequisites**

Confirm that:
1. standard-tooling has been released with the check name registry update
2. standard-actions has been released with the workflow renames

- [ ] **Step 2: Update the `SA_TAG` in the script**

Edit `scripts/fleet-cicd-rename.sh` and set `SA_TAG` to the actual
standard-actions release tag (e.g., `v1.5.17`).

- [ ] **Step 3: Dry run on one repo**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-namespace
./scripts/fleet-cicd-rename.sh standard-tooling
```

Review the PR that gets created. Verify:
- ci.yml has `version:` job key pointing to `ci-version-bump.yml`
- cd.yml exists with `release:` and `docs:` jobs
- Old `publish-release.yml` and `publish-docs.yml` are deleted

- [ ] **Step 4: Run across remaining repos**

```bash
./scripts/fleet-cicd-rename.sh all
```

- [ ] **Step 5: Update branch protection rules**

After PRs are merged, run the standard-tooling ruleset sync for each repo
to update branch protection from `release / version-bump` to
`version / version-bump`:

```bash
for repo in standard-tooling standard-tooling-docker standard-tooling-plugin \
  mq-rest-admin-python mq-rest-admin-go mq-rest-admin-ruby \
  mq-rest-admin-java mq-rest-admin-rust mq-rest-admin-common \
  mq-rest-admin-dev-environment ai-research-methodology; do
  echo "=== $repo ==="
  st-github-config sync --repo "wphillipmoore/$repo"
done
```

- [ ] **Step 6: Verify one repo end-to-end**

Pick a repo (e.g., `mq-rest-admin-python`). Push a test branch and
verify that CI checks produce the expected names:
- `version / version-bump` (not `release / version-bump`)
- All other check names unchanged

---

## Notes

### standard-tooling-docker special case

This repo has a `docker-publish.yml` workflow that is repo-specific (not
from standard-actions). It is not renamed — repo-specific workflows are
outside the CI/CD namespace convention. The rollout script only touches
standard-actions-backed workflows.

### `PublishConfig` class naming

The `PublishConfig` / `DesiredPublishConfig` classes in standard-tooling
and the `[publish]` TOML section are not renamed in this change. They
hold boolean flags (`release`, `docs`) and don't reference workflow
filenames. Renaming them to `CdConfig` / `[cd]` would be a clean
follow-up but is not required for the namespace convention to work.

### Deployment race conditions

If standard-actions releases before standard-tooling, the CI gates
ruleset sync would expect `release / version-bump` but CI would produce
`version / version-bump`. Temporarily disable the ruleset sync or
manually update branch protection rules to bridge the gap. At fleet
scale of one maintainer, this is manageable.
