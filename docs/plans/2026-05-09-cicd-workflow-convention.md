# CI/CD Workflow Convention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename workflow files from `publish-*` to `cd-*` and `ci-release` to `ci-version-bump`, standardize YAML formatting across the fleet, and create a canonical README with conventions and examples.

**Architecture:** Five-phase rollout: (1) update standard-tooling's check name registry and workflows, (2) rename and reformat standard-actions workflows + create README, (3) update standard-actions documentation, (4) release both repos, (5) scripted fleet sweep across remaining 10 consumer repos. standard-tooling must release first because its ruleset sync tool enforces check names.

**Tech Stack:** GitHub Actions YAML, Python (standard-tooling), Shell (rollout script), gh CLI

**Spec:** `docs/specs/2026-05-09-cicd-workflow-convention-design.md` (on branch `feature/383-cicd-convention`)

---

## File Map

### standard-tooling (`/Users/pmoore/dev/github/standard-tooling`)

| Action | Path |
|---|---|
| Modify | `src/standard_tooling/lib/github_config.py:283-285` |
| Modify | `tests/standard_tooling/test_github_config_lib.py:272-279` |
| Delete | `.github/workflows/publish-release.yml` |
| Delete | `.github/workflows/publish-docs.yml` |
| Create | `.github/workflows/cd.yml` |
| Modify | `.github/workflows/ci.yml:22-75` |

### standard-actions (worktree: `.worktrees/issue-383-cicd-convention/`)

| Action | Path |
|---|---|
| Rename | `.github/workflows/ci-release.yml` → `.github/workflows/ci-version-bump.yml` |
| Rename | `.github/workflows/publish-release.yml` → `.github/workflows/cd-release.yml` |
| Rename | `.github/workflows/publish-docs.yml` → `.github/workflows/cd-docs.yml` |
| Rename | `.github/workflows/publish.yml` → `.github/workflows/cd.yml` |
| Modify | `.github/workflows/ci.yml:30-34` |
| Create | `.github/workflows/README.md` |
| Rename | `docs/site/docs/workflows/ci-release.md` → `docs/site/docs/workflows/ci-version-bump.md` |
| Modify | `docs/site/docs/workflows/index.md` |
| Modify | `docs/site/docs/ci-gates/required-checks.md` |
| Modify | `docs/site/docs/index.md` |
| Modify | `docs/site/docs/configuration.md` |
| Modify | `docs/site/mkdocs.yml:87` |
| Modify | `docs/development/publish-workflow.md` |
| Modify | `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md` |

### Fleet sweep (10 repos via rollout script)

| Action | Path (per repo) |
|---|---|
| Rewrite | `.github/workflows/ci.yml` |
| Delete | `.github/workflows/publish-release.yml` |
| Delete | `.github/workflows/publish-docs.yml` |
| Create | `.github/workflows/cd.yml` |

---

## Phase 1: standard-tooling Changes

All Phase 1 work happens in the standard-tooling repository at
`/Users/pmoore/dev/github/standard-tooling`. Create a feature branch
before starting (e.g., `feature/383-cicd-namespace`).

### Task 1: Update check name registry (TDD)

**Files:**
- Modify: `tests/standard_tooling/test_github_config_lib.py:272-279`
- Modify: `src/standard_tooling/lib/github_config.py:283-285`

- [ ] **Step 1: Update tests to expect new check name**

In `tests/standard_tooling/test_github_config_lib.py`, change the two
test functions at lines 272-279:

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

- [ ] **Step 3: Update the check name string**

In `src/standard_tooling/lib/github_config.py`, change lines 283-285
from:

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- pytest tests/standard_tooling/test_github_config_lib.py -v`

Expected: All tests PASS.

- [ ] **Step 5: Run full test suite**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- pytest -v`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling
st-commit --type feat --scope github-config --message "rename release/version-bump check to version/version-bump (#383)" --agent claude
```

---

### Task 2: Rename standard-tooling workflows + reformat ci.yml

**Files:**
- Delete: `.github/workflows/publish-release.yml`
- Delete: `.github/workflows/publish-docs.yml`
- Create: `.github/workflows/cd.yml`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Create `cd.yml` merging the two publish callers**

Create `.github/workflows/cd.yml` with this content:

```yaml
name: CD

on:
  push:
    branches: [develop, main]
  workflow_dispatch:

permissions:
  attestations: write
  contents: write
  id-token: write
  pull-requests: write

jobs:
  docs:
    uses: wphillipmoore/standard-actions/.github/workflows/cd-docs.yml@v1.5
    permissions:
      contents: write

  release:
    if: github.ref == 'refs/heads/main'
    uses: wphillipmoore/standard-actions/.github/workflows/cd-release.yml@v1.5
    with:
      language: python
    secrets: inherit
```

- [ ] **Step 2: Delete old publish workflow files**

```bash
cd /Users/pmoore/dev/github/standard-tooling
git rm .github/workflows/publish-release.yml .github/workflows/publish-docs.yml
```

- [ ] **Step 3: Rewrite ci.yml (remove banners, alphabetical ordering, rename release → version)**

Replace the full contents of `.github/workflows/ci.yml` with:

```yaml
name: CI

on:
  pull_request:
  workflow_call:
    inputs:
      run-security:
        type: boolean
        default: true
      run-release:
        type: boolean
        default: true

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  audit:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-audit.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  quality:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-quality.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'
      container-tag: '3.14'
      container-suffix: python

  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: python
      run-standards: ${{ inputs.run-release != false }}
      run-security: ${{ inputs.run-security != false }}
      container-tag: '3.14'
      container-suffix: python

  test:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-test.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: python
      run-release: ${{ inputs.run-release != false }}
      container-tag: '3.14'
      container-suffix: python
```

Changes from current ci.yml:
- Removed banner comments (`# --------...`)
- Removed `# All jobs delegate to standard-actions reusable workflows.` comment
- Reordered jobs alphabetically: audit, quality, security, test, version
- Renamed `release` job key → `version`
- Updated `uses:` path from `ci-release.yml` to `ci-version-bump.yml`
- Removed string comparison for boolean inputs (`!= 'false'` → `!= false`)
  — the `run-standards` and `run-security` inputs were already `type: boolean`
  so bare `false` is correct

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling
git add .github/workflows/cd.yml
st-commit --type feat --scope ci --message "rename publish workflows to cd convention, reformat ci.yml (#383)" --agent claude
```

---

## Phase 2: standard-actions Workflow Renames

All Phase 2-3 work happens in the standard-actions worktree:
`/Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention/`

The worktree should be on branch `feature/383-cicd-convention` which
already has the combined spec committed.

### Task 3: Rename ci-release.yml → ci-version-bump.yml + update ci.yml

**Files:**
- Rename: `.github/workflows/ci-release.yml` → `.github/workflows/ci-version-bump.yml`
- Modify: `.github/workflows/ci.yml:30-34`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git mv .github/workflows/ci-release.yml .github/workflows/ci-version-bump.yml
```

- [ ] **Step 2: Update the workflow `name:` field**

In `.github/workflows/ci-version-bump.yml`, change line 1:

```yaml
name: CI Release
```

to:

```yaml
name: CI Version Bump
```

- [ ] **Step 3: Update ci.yml job key and uses path**

In `.github/workflows/ci.yml`, change lines 30-34:

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

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
st-commit --type feat --scope ci --message "rename ci-release.yml to ci-version-bump.yml (#383)" --agent claude
```

---

### Task 4: Rename publish-release.yml → cd-release.yml

**Files:**
- Rename: `.github/workflows/publish-release.yml` → `.github/workflows/cd-release.yml`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git mv .github/workflows/publish-release.yml .github/workflows/cd-release.yml
```

- [ ] **Step 2: Update the workflow `name:` field and remove decorative separators**

In `.github/workflows/cd-release.yml`, change:

```yaml
name: Publish release
```

to:

```yaml
name: CD Release
```

Also remove the three decorative separator comments:

```yaml
      # ── Version and gate checks ────────────────────────────────────
```

```yaml
      # ── Release pipeline (gated on new tag) ────────────────────────
```

```yaml
      # ── Tag, release, and post-release ─────────────────────────────
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

- [ ] **Step 4: Rename the inner job name**

In `.github/workflows/cd-release.yml`, change:

```yaml
jobs:
  publish:
    name: release
```

to:

```yaml
jobs:
  release:
    name: release
```

- [ ] **Step 5: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
st-commit --type feat --scope cd --message "rename publish-release.yml to cd-release.yml (#383)" --agent claude
```

---

### Task 5: Split publish-docs.yml → cd-docs.yml

**Files:**
- Rename: `.github/workflows/publish-docs.yml` → `.github/workflows/cd-docs.yml`

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git mv .github/workflows/publish-docs.yml .github/workflows/cd-docs.yml
```

- [ ] **Step 2: Strip push triggers and update name**

In `.github/workflows/cd-docs.yml`, change:

```yaml
name: Publish docs

on:
  push:
    branches: [develop, main]
  workflow_dispatch:
  workflow_call:
    inputs:
      pre-deploy-command:
        description: Shell command to run before deploy.
        type: string
        default: ""
      mkdocs-config:
        description: Path to mkdocs.yml configuration file.
        type: string
        default: docs/site/mkdocs.yml
```

to:

```yaml
name: CD Docs

on:
  workflow_call:
    inputs:
      pre-deploy-command:
        description: Shell command to run before deploy.
        type: string
        default: ""
      mkdocs-config:
        description: Path to mkdocs.yml configuration file.
        type: string
        default: docs/site/mkdocs.yml
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

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
st-commit --type feat --scope cd --message "split publish-docs.yml into cd-docs.yml (workflow_call only) (#383)" --agent claude
```

---

### Task 6: Rename publish.yml → cd.yml (absorb docs trigger)

**Files:**
- Rename: `.github/workflows/publish.yml` → `.github/workflows/cd.yml`

This is the bespoke local workflow for standard-actions. It has inline
steps (freeze-internal-refs, tag-and-release, version-bump-pr) that are
unique to this repo. The logic is preserved — only the naming, triggers,
and a new docs job are changed.

- [ ] **Step 1: Rename the file**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
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

- [ ] **Step 3: Rename the job and add main-only condition**

In `.github/workflows/cd.yml`, change:

```yaml
jobs:
  publish:
    name: "publish / release"
    runs-on: ubuntu-latest
```

to:

```yaml
jobs:
  release:
    name: "cd / release"
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
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

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
st-commit --type feat --scope cd --message "rename publish.yml to cd.yml umbrella with docs job (#383)" --agent claude
```

---

## Phase 3: standard-actions Documentation

### Task 7: Create .github/workflows/README.md

**Files:**
- Create: `.github/workflows/README.md`

- [ ] **Step 1: Write the README**

Create `.github/workflows/README.md` with this content:

````markdown
# Workflow Conventions

Canonical reference for workflow file naming, formatting, and structure
across all managed repositories.

## Naming Convention

| Pattern | Role | Trigger |
|---|---|---|
| `ci.yml` | Local CI umbrella | `pull_request` |
| `ci-*.yml` | Reusable pre-merge gate | `workflow_call` |
| `cd.yml` | Local CD umbrella | `push` to main/develop |
| `cd-*.yml` | Reusable post-merge delivery | `workflow_call` |

**Bare name** (`ci.yml`, `cd.yml`) = local entry point.
**Hyphenated** (`ci-quality.yml`, `cd-release.yml`) = reusable workflow.

## Available Reusable Workflows

### CI (pre-merge)

| Workflow | Purpose |
|---|---|
| `ci-quality.yml` | Common linting, language-specific lint and typecheck |
| `ci-security.yml` | Standards compliance and security scanning |
| `ci-test.yml` | Unit and integration tests |
| `ci-audit.yml` | Dependency audit |
| `ci-version-bump.yml` | Version divergence gate |

### CD (post-merge)

| Workflow | Purpose |
|---|---|
| `cd-release.yml` | Full release pipeline (tag, build, publish, version bump) |
| `cd-docs.yml` | MkDocs documentation deployment |

## Formatting Rules

### File-level structure (top to bottom)

1. Reference comment (consumer repos only — see below)
2. `name:`
3. `on:`
4. `permissions:` (if needed at workflow level)
5. `concurrency:` (if needed)
6. `jobs:` — entries in **alphabetical order** by job key

### Job ordering

Alphabetical by job key. Always. No exceptions.

### Comments

- No section banners or decorative separators.
- No redundant labels that restate the job key.
- Comments only when the YAML itself does not convey intent (e.g.,
  a workaround, a non-obvious constraint).
- No `# yamllint disable-line` pragmas — fix the YAML instead.

### Whitespace

- One blank line between top-level keys (`on:`, `permissions:`, `jobs:`).
- One blank line between jobs within the `jobs:` block.
- No trailing blank lines at end of file.

### Reference comment

Every consuming repo's workflow files include on line 1:

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
```

Rules:
- Line 1, always — before `name:`.
- Just the raw URL, no surrounding prose.
- Points to the `develop` branch.
- standard-actions' own workflow files skip this (README is co-located).

### Standardized `workflow_call` inputs

- Boolean toggles use `type: boolean` (not `type: string`).
- Version matrix input is always named `versions` (not `go-versions`,
  `ruby-versions`, etc.).

## Examples

### ci.yml — Shell (no version matrix)

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
name: CI

on:
  pull_request:

permissions:
  contents: read
  security-events: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-quality.yml@v1.5
    with:
      language: shell
      versions: '["latest"]'
      container-suffix: base

  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: shell

  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: shell
```

### ci.yml — Versioned language (full)

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
name: CI

on:
  pull_request:
  workflow_call:
    inputs:
      run-security:
        type: boolean
        default: true
      run-release:
        type: boolean
        default: true

permissions:
  contents: read
  security-events: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  audit:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-audit.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  quality:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-quality.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'
      container-tag: '3.14'
      container-suffix: python

  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.5
    permissions:
      contents: read
      security-events: write
    with:
      language: python
      run-standards: ${{ inputs.run-release != false }}
      run-security: ${{ inputs.run-security != false }}
      container-tag: '3.14'
      container-suffix: python

  test:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-test.yml@v1.5
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: python
      run-release: ${{ inputs.run-release != false }}
      container-tag: '3.14'
      container-suffix: python
```

### cd.yml — Release + Docs

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
name: CD

on:
  push:
    branches: [develop, main]
  workflow_dispatch:

permissions:
  attestations: write
  contents: write
  id-token: write
  pull-requests: write

jobs:
  docs:
    uses: wphillipmoore/standard-actions/.github/workflows/cd-docs.yml@v1.5
    permissions:
      contents: write

  release:
    if: github.ref == 'refs/heads/main'
    uses: wphillipmoore/standard-actions/.github/workflows/cd-release.yml@v1.5
    with:
      language: python
    secrets: inherit
```

### cd.yml — Release only (no docs)

```yaml
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md
name: CD

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  attestations: write
  contents: write
  id-token: write
  pull-requests: write

jobs:
  release:
    uses: wphillipmoore/standard-actions/.github/workflows/cd-release.yml@v1.5
    with:
      language: python
    secrets: inherit
```
````

- [ ] **Step 2: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git add .github/workflows/README.md
st-commit --type docs --scope workflows --message "add workflow conventions README (#383)" --agent claude
```

---

### Task 8: Update site documentation

**Files:**
- Rename: `docs/site/docs/workflows/ci-release.md` → `docs/site/docs/workflows/ci-version-bump.md`
- Modify: `docs/site/docs/workflows/index.md:24`
- Modify: `docs/site/docs/ci-gates/required-checks.md:65`
- Modify: `docs/site/docs/index.md:35`
- Modify: `docs/site/docs/configuration.md:209`
- Modify: `docs/site/mkdocs.yml:87`

- [ ] **Step 1: Rename and rewrite ci-release.md → ci-version-bump.md**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git mv docs/site/docs/workflows/ci-release.md docs/site/docs/workflows/ci-version-bump.md
```

Replace the full contents of `docs/site/docs/workflows/ci-version-bump.md`
with:

```markdown
# ci-version-bump

Version divergence gate workflow.

## Inputs

| Input | Type | Required | Default | Description |
| ------- | ------ | ---------- | --------- | ------------- |
| `language` | string | yes | — | Primary language of the repository |
| `run-release` | boolean | no | `true` | Run the version-bump verification job |

## Jobs and check names

| Job | Check name | Condition |
| ----- | ------------ | ----------- |
| `version-bump` | `CI Version Bump / version-bump` | `run-release` is true |

## Usage

```yaml
jobs:
  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: python
```

To skip version gates (e.g., for infrastructure repos that don't version):

```yaml
jobs:
  version:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-version-bump.yml@v1.5
    with:
      language: shell
      run-release: false
```
```

- [ ] **Step 2: Update workflows/index.md**

In `docs/site/docs/workflows/index.md`, change line 24:

```markdown
| [CI Release](ci-release.md) | `ci-release.yml` | Release gate verification |
```

to:

```markdown
| [CI Version Bump](ci-version-bump.md) | `ci-version-bump.yml` | Version divergence gate |
```

- [ ] **Step 3: Update ci-gates/required-checks.md**

In `docs/site/docs/ci-gates/required-checks.md`, change line 65:

```markdown
| `ci-release.yml` | `CI Release / version-bump` |
```

to:

```markdown
| `ci-version-bump.yml` | `CI Version Bump / version-bump` |
```

- [ ] **Step 4: Update index.md**

In `docs/site/docs/index.md`, change line 35:

```markdown
| [ci-release](workflows/ci-release.md) | Release gate verification |
```

to:

```markdown
| [ci-version-bump](workflows/ci-version-bump.md) | Version divergence gate |
```

- [ ] **Step 5: Update configuration.md**

In `docs/site/docs/configuration.md`, change line 209:

```markdown
- [ ] Add `publish.yml` if the repository publishes versioned artifacts
```

to:

```markdown
- [ ] Add `cd.yml` if the repository publishes versioned artifacts
```

- [ ] **Step 6: Update mkdocs.yml nav**

In `docs/site/mkdocs.yml`, change line 87:

```yaml
      - ci-release: workflows/ci-release.md
```

to:

```yaml
      - ci-version-bump: workflows/ci-version-bump.md
```

- [ ] **Step 7: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git add docs/site/
st-commit --type docs --scope site --message "update site docs for CI/CD namespace convention (#383)" --agent claude
```

---

### Task 9: Update development + spec documentation

**Files:**
- Modify: `docs/development/publish-workflow.md:1-4`
- Modify: `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`

- [ ] **Step 1: Update publish-workflow.md header**

In `docs/development/publish-workflow.md`, change lines 1-4:

```markdown
# Publish workflow ordering

Each consuming repository has a `publish.yml` workflow that runs on push to
`main`. While the specific build, publish, and version-bump steps are
```

to:

```markdown
# CD workflow ordering

Each consuming repository has a `cd.yml` workflow that runs on push to
`main`. While the specific build, publish, and version-bump steps are
```

- [ ] **Step 2: Add superseded note to rationalization spec**

In `docs/specs/2026-05-05-publish-and-docs-rationalization-design.md`,
after the header line (`# ...`), add:

```markdown

> **Note:** The `publish-*` naming convention in this spec has been
> superseded by the CI/CD workflow convention
> ([#383](https://github.com/wphillipmoore/standard-actions/issues/383)).
> `publish-release.yml` → `cd-release.yml`, `publish-docs.yml` →
> `cd-docs.yml`. Architectural decisions (thin callers, workflow_call
> interfaces) remain valid.
```

- [ ] **Step 3: Find and update any remaining references**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
grep -rn "publish-release\.yml\|publish-docs\.yml\|ci-release\.yml\|publish\.yml" docs/ --include="*.md" | grep -v "/plans/" | grep -v "2026-05-09-cicd-workflow-convention" | grep -v "2026-05-05-ci-workflow-reset" | grep -v "2026-05-06-self-referential"
```

For each remaining reference found, update to the new filename:
- `ci-release.yml` → `ci-version-bump.yml`
- `publish-release.yml` → `cd-release.yml`
- `publish-docs.yml` → `cd-docs.yml`
- `publish.yml` → `cd.yml`

Historical specs (`ci-workflow-reset`, `self-referential-tagged-action-refs`)
use the old names in their original context — leave those unchanged since
they document decisions made at that time.

- [ ] **Step 4: Validate**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
st-commit --type docs --scope specs --message "update documentation for CI/CD workflow convention (#383)" --agent claude
```

---

## Phase 4: Validate + Release

### Task 10: Validate and PR standard-actions

- [ ] **Step 1: Full validation**

Run: `cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention && st-docker-run -- st-validate`

Expected: PASS.

- [ ] **Step 2: Verify final workflow layout**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
ls -1 .github/workflows/
```

Expected output:

```
README.md
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
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git push -u origin feature/383-cicd-convention
```

Create PR targeting develop with title:
`feat(ci): adopt CI/CD workflow convention (#383, #387)`

---

### Task 11: Release standard-tooling

This task is manual. standard-tooling must release before
standard-actions so the check name registry is updated fleet-wide.

- [ ] **Step 1: Merge standard-tooling PR and release**

Follow the standard release process to cut a new standard-tooling
version containing the check name registry update and workflow renames.

---

### Task 12: Release standard-actions

This task is manual.

- [ ] **Step 1: Merge standard-actions PR and release**

After standard-tooling has released, merge the standard-actions PR and
follow the standard release process to cut a v1.5.x release containing
the workflow renames, README, and documentation updates.

---

## Phase 5: Fleet Sweep

### Task 13: Write rollout script

**Files:**
- Create: `scripts/fleet-cicd-rename.sh`

The script operates on a single repo at a time. It expects repos at
`/Users/pmoore/dev/github/<repo-name>`. It is idempotent (safe to
re-run).

The script handles both naming (renames) and formatting (alphabetical
ordering, reference comments, no banners, standardized inputs).

- [ ] **Step 1: Write the rollout script**

Create `scripts/fleet-cicd-rename.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Fleet-wide CI/CD workflow convention rollout.
# Renames publish-* → cd-*, ci-release → ci-version-bump.
# Reformats ci.yml: alphabetical job ordering, reference comment,
# no banners, standardized inputs.
#
# Usage: fleet-cicd-rename.sh <repo-name|all>

GITHUB_BASE="/Users/pmoore/dev/github"
GITHUB_ORG="wphillipmoore"
BRANCH="chore/383-cicd-workflow-convention"
SA_TAG="v1.5"  # Update to actual release tag

REPOS=(
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

  # --- CI workflow: rewrite with formatting convention ---
  if [ -f "$wf/ci.yml" ]; then
    if grep -q "ci-release\.yml" "$wf/ci.yml"; then
      sed -i.bak \
        -e 's|ci-release\.yml|ci-version-bump.yml|g' \
        "$wf/ci.yml"
      rm -f "$wf/ci.yml.bak"
    fi

    # Rename job key: "  release:" -> "  version:"
    if grep -q "^  release:" "$wf/ci.yml"; then
      sed -i.bak \
        -e 's/^  release:$/  version:/' \
        "$wf/ci.yml"
      rm -f "$wf/ci.yml.bak"
    fi

    # Remove banner comments
    sed -i.bak \
      -e '/^  # ---/d' \
      -e '/^  # ====/d' \
      "$wf/ci.yml"
    rm -f "$wf/ci.yml.bak"

    # Add reference comment if not present
    if ! grep -q "README.md" "$wf/ci.yml"; then
      sed -i.bak \
        "1i\\
# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md" \
        "$wf/ci.yml"
      rm -f "$wf/ci.yml.bak"
    fi

    # Rename language-prefixed version inputs to 'versions'
    sed -i.bak \
      -e 's/go-versions:/versions:/' \
      -e 's/ruby-versions:/versions:/' \
      -e 's/java-versions:/versions:/' \
      -e 's/rust-versions:/versions:/' \
      -e 's/python-versions:/versions:/' \
      "$wf/ci.yml"
    rm -f "$wf/ci.yml.bak"

    # Remove yamllint pragmas
    sed -i.bak \
      -e '/# yamllint disable-line/d' \
      "$wf/ci.yml"
    rm -f "$wf/ci.yml.bak"

    echo "  Updated ci.yml"
  fi

  # --- Merge publish callers into cd.yml ---
  local has_release=false
  local has_docs=false

  if [ -f "$wf/publish-release.yml" ]; then
    has_release=true
  fi

  if [ -f "$wf/publish-docs.yml" ]; then
    has_docs=true
  fi

  if $has_release || $has_docs; then
    {
      echo "# https://github.com/wphillipmoore/standard-actions/blob/develop/.github/workflows/README.md"
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

      if $has_docs; then
        echo "  docs:"
        echo "    uses: ${GITHUB_ORG}/standard-actions/.github/workflows/cd-docs.yml@${SA_TAG}"
        echo "    permissions:"
        echo "      contents: write"
      fi

      if $has_release; then
        if $has_docs; then
          echo ""
        fi
        echo "  release:"
        if $has_docs; then
          echo "    if: github.ref == 'refs/heads/main'"
        fi
        echo "    uses: ${GITHUB_ORG}/standard-actions/.github/workflows/cd-release.yml@${SA_TAG}"

        # Extract the 'with:' block from publish-release.yml
        local with_block
        with_block=$(sed -n '/^    with:/,/^    [a-z]/{ /^    with:/p; /^      /p; }' "$wf/publish-release.yml" 2>/dev/null || true)
        if [ -n "$with_block" ]; then
          echo "$with_block"
        fi

        echo "    secrets: inherit"
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
    --message "adopt CI/CD workflow convention (#383)" \
    --agent claude

  git push -u origin "$BRANCH"

  gh pr create \
    --title "feat(ci): adopt CI/CD workflow convention (#383)" \
    --body "$(cat <<'PREOF'
## Summary

- Rename `ci-release.yml` ref → `ci-version-bump.yml` (job key: `release` → `version`)
- Merge `publish-release.yml` + `publish-docs.yml` into `cd.yml` umbrella
- Add reference comment to ci.yml
- Remove banner comments and yamllint pragmas
- Standardize version input naming

Refs: wphillipmoore/standard-actions#383

## Test plan

- [ ] CI passes with new check names
- [ ] CD workflow triggers correctly on push to main
PREOF
)" \
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
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
chmod +x scripts/fleet-cicd-rename.sh
```

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
git add scripts/fleet-cicd-rename.sh
st-commit --type feat --scope scripts --message "add fleet-wide CI/CD workflow convention rollout script (#383)" --agent claude
```

---

### Task 14: Execute fleet sweep

- [ ] **Step 1: Verify prerequisites**

Confirm that:
1. standard-tooling has released with the check name registry update
2. standard-actions has released with the workflow renames

- [ ] **Step 2: Update `SA_TAG` in the script**

Edit `scripts/fleet-cicd-rename.sh` and set `SA_TAG` to the actual
standard-actions release tag (e.g., `v1.5.17`).

- [ ] **Step 3: Dry run on one repo**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-383-cicd-convention
./scripts/fleet-cicd-rename.sh mq-rest-admin-common
```

Review the PR. Verify:
- ci.yml has reference comment on line 1
- ci.yml has `version:` job key pointing to `ci-version-bump.yml`
- ci.yml has no banner comments
- cd.yml exists with alphabetically ordered `docs:` and `release:` jobs
- Old `publish-release.yml` and `publish-docs.yml` are deleted

- [ ] **Step 4: Run across remaining repos**

```bash
./scripts/fleet-cicd-rename.sh all
```

- [ ] **Step 5: Update branch protection rules**

After PRs are merged, run the standard-tooling ruleset sync for each
repo to update branch protection from `release / version-bump` to
`version / version-bump`:

```bash
for repo in standard-tooling-docker standard-tooling-plugin \
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

`docker-publish.yml` is repo-specific and not touched by the rollout
script. It stays as-is.

### `PublishConfig` class naming

`PublishConfig` / `DesiredPublishConfig` classes in standard-tooling
and the `[publish]` TOML section are not renamed. They hold boolean
flags, not workflow filenames. Renaming to `CdConfig` / `[cd]` is a
clean follow-up but not required.

### Deployment race conditions

If standard-actions releases before standard-tooling, the CI gates
ruleset sync would expect `release / version-bump` but CI would produce
`version / version-bump`. Temporarily disable the ruleset sync or
manually update branch protection rules to bridge the gap. At fleet
scale of one maintainer, this is manageable.

### Alphabetical ordering for ci.yml reformatting

The rollout script does not reorder jobs (only renames and removes
banners). Alphabetical reordering of jobs in consumer repos' ci.yml
files should be done manually per the per-repo specs in Part 4 of the
design spec. The script handles the mechanical renames; the formatting
adjustments may need manual review for repos with bespoke jobs.

### Superseded specs

This plan supersedes:
- `docs/plans/2026-05-09-cicd-namespace-convention.md`

The original spec files (`cicd-namespace-convention-design.md` and
`ci-yaml-standardization-design.md`) were combined into
`cicd-workflow-convention-design.md` on the feature branch.
