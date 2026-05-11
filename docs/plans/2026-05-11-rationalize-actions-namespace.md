# Rationalize actions/ namespace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the `actions/` directory to mirror the workflow
namespace hierarchy (`phase/domain/action`), making navigation from
workflow file to composite action mechanical and intuitive.

**Architecture:** Move all 12 composite actions into a four-bucket
top-level structure (`ci/`, `cd/`, `shared/`, `local/`), update every
`uses:` reference in workflow and action files, harmonize the one
input name mismatch, delete dead code (`python/setup`), and update all
documentation. Single atomic PR — no deprecation shims.

**Spec:**
[`docs/specs/2026-05-11-rationalize-actions-namespace-design.md`](../specs/2026-05-11-rationalize-actions-namespace-design.md)

**Worktree:** `.worktrees/issue-440-rationalize-namespace/`
**Branch:** `feature/440-rationalize-namespace`

---

## Task 1: Move action directories to new namespace

**Files:**
- Move: all 12 action directories (see move list below)
- Delete: `actions/python/setup/`

This task creates the new directory structure. No file content changes
yet — just `git mv` and `rm`.

- [ ] **Step 1: Create destination directories**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

mkdir -p actions/ci/security
mkdir -p actions/ci/version-bump
mkdir -p actions/cd/release
mkdir -p actions/cd/docs
mkdir -p actions/shared/security
mkdir -p actions/shared/setup
mkdir -p actions/local
```

- [ ] **Step 2: Move CI actions**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git mv actions/standards-compliance    actions/ci/security/standards-compliance
git mv actions/security/codeql         actions/ci/security/codeql
git mv actions/security/semgrep        actions/ci/security/semgrep
git mv actions/release-gates/version-divergence actions/ci/version-bump/version-divergence
```

- [ ] **Step 3: Move CD actions**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git mv actions/publish/validate-inputs    actions/cd/release/validate-inputs
git mv actions/publish/registry-publish   actions/cd/release/registry-publish
git mv actions/publish/tag-and-release    actions/cd/release/tag-and-release
git mv actions/publish/version-bump-pr    actions/cd/release/version-bump-pr
git mv actions/docs-deploy                actions/cd/docs/deploy
```

- [ ] **Step 4: Move shared actions**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git mv actions/security/trivy          actions/shared/security/trivy
git mv actions/setup/standard-tooling  actions/shared/setup/standard-tooling
```

- [ ] **Step 5: Move local actions**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git mv actions/publish/freeze-internal-refs actions/local/freeze-internal-refs
```

- [ ] **Step 6: Delete dead code and empty directories**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

rm -rf actions/python
rmdir actions/security actions/release-gates actions/publish actions/setup actions/docs-deploy 2>/dev/null
```

Note: `rmdir` will only remove directories if empty. Some may have
already been removed by `git mv`. Ignore errors from already-removed
directories.

- [ ] **Step 7: Verify directory structure**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

find actions -name action.yml | sort
```

Expected output:
```
actions/cd/docs/deploy/action.yml
actions/cd/release/registry-publish/action.yml
actions/cd/release/tag-and-release/action.yml
actions/cd/release/validate-inputs/action.yml
actions/cd/release/version-bump-pr/action.yml
actions/ci/security/codeql/action.yml
actions/ci/security/semgrep/action.yml
actions/ci/security/standards-compliance/action.yml
actions/ci/version-bump/version-divergence/action.yml
actions/local/freeze-internal-refs/action.yml
actions/shared/security/trivy/action.yml
actions/shared/setup/standard-tooling/action.yml
```

12 actions. No `python/setup`. No old directories remaining.

- [ ] **Step 8: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add -A actions/
st-commit --type refactor --scope actions --message "move actions to phase/domain/action namespace hierarchy (#440)" --agent claude
```

---

## Task 2: Update workflow local path references

**Files:**
- Modify: `.github/workflows/ci-security.yml` (lines 58, 61, 74, 89, 105)
- Modify: `.github/workflows/ci-version-bump.yml` (lines 44, 47)
- Modify: `.github/workflows/ci-quality.yml` (lines 42, 59, 80)
- Modify: `.github/workflows/ci-test.yml` (line 39)
- Modify: `.github/workflows/ci-audit.yml` (line 39)
- Modify: `.github/workflows/cd-release.yml` (lines 92, 132)
- Modify: `.github/workflows/cd-docs.yml` (lines 38, 48)
- Modify: `.github/workflows/cd.yml` (lines 44, 64)
- Modify: `.github/workflows/ops-github-config.yml` (line 18)

- [ ] **Step 1: Update ci-security.yml**

In `.github/workflows/ci-security.yml`, make these replacements:

| Line | Old | New |
|------|-----|-----|
| 58 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 61 | `uses: ./actions/standards-compliance` | `uses: ./actions/ci/security/standards-compliance` |
| 74 | `uses: ./actions/security/codeql` | `uses: ./actions/ci/security/codeql` |
| 89 | `uses: ./actions/security/trivy` | `uses: ./actions/shared/security/trivy` |
| 105 | `uses: ./actions/security/semgrep` | `uses: ./actions/ci/security/semgrep` |

- [ ] **Step 2: Update ci-version-bump.yml**

In `.github/workflows/ci-version-bump.yml`:

| Line | Old | New |
|------|-----|-----|
| 44 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 47 | `uses: ./actions/release-gates/version-divergence` | `uses: ./actions/ci/version-bump/version-divergence` |

- [ ] **Step 3: Update ci-quality.yml**

In `.github/workflows/ci-quality.yml`:

| Line | Old | New |
|------|-----|-----|
| 42 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 59 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 80 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |

- [ ] **Step 4: Update ci-test.yml**

In `.github/workflows/ci-test.yml`:

| Line | Old | New |
|------|-----|-----|
| 39 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |

- [ ] **Step 5: Update ci-audit.yml**

In `.github/workflows/ci-audit.yml`:

| Line | Old | New |
|------|-----|-----|
| 39 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |

- [ ] **Step 6: Update cd-release.yml (local refs only)**

In `.github/workflows/cd-release.yml`:

| Line | Old | New |
|------|-----|-----|
| 92 | `uses: ./actions/publish/validate-inputs` | `uses: ./actions/cd/release/validate-inputs` |
| 132 | `uses: ./actions/publish/registry-publish` | `uses: ./actions/cd/release/registry-publish` |

- [ ] **Step 7: Update cd-docs.yml**

In `.github/workflows/cd-docs.yml`:

| Line | Old | New |
|------|-----|-----|
| 38 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 48 | `uses: ./actions/docs-deploy` | `uses: ./actions/cd/docs/deploy` |

- [ ] **Step 8: Update cd.yml (local refs only)**

In `.github/workflows/cd.yml`:

| Line | Old | New |
|------|-----|-----|
| 44 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |
| 64 | `uses: ./actions/publish/freeze-internal-refs` | `uses: ./actions/local/freeze-internal-refs` |

- [ ] **Step 9: Update ops-github-config.yml**

In `.github/workflows/ops-github-config.yml`:

| Line | Old | New |
|------|-----|-----|
| 18 | `uses: ./actions/setup/standard-tooling` | `uses: ./actions/shared/setup/standard-tooling` |

- [ ] **Step 10: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add .github/workflows/
st-commit --type refactor --scope workflows --message "update local action paths to new namespace (#440)" --agent claude
```

---

## Task 3: Update workflow remote ref paths

**Files:**
- Modify: `.github/workflows/cd-release.yml` (lines 99, 150, 181)
- Modify: `.github/workflows/cd.yml` (lines 70, 76)

- [ ] **Step 1: Update cd-release.yml remote refs**

In `.github/workflows/cd-release.yml`:

| Line | Old | New |
|------|-----|-----|
| 99 | `uses: wphillipmoore/standard-actions/actions/setup/standard-tooling@develop` | `uses: wphillipmoore/standard-actions/actions/shared/setup/standard-tooling@develop` |
| 150 | `uses: wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `uses: wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| 181 | `uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `uses: wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |

- [ ] **Step 2: Update cd.yml remote refs**

In `.github/workflows/cd.yml`:

| Line | Old | New |
|------|-----|-----|
| 70 | `uses: wphillipmoore/standard-actions/actions/publish/tag-and-release@develop` | `uses: wphillipmoore/standard-actions/actions/cd/release/tag-and-release@develop` |
| 76 | `uses: wphillipmoore/standard-actions/actions/publish/version-bump-pr@develop` | `uses: wphillipmoore/standard-actions/actions/cd/release/version-bump-pr@develop` |

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add .github/workflows/cd-release.yml .github/workflows/cd.yml
st-commit --type refactor --scope workflows --message "update remote action refs to new namespace (#440)" --agent claude
```

---

## Task 4: Update action-to-action references

**Files:**
- Modify: `actions/ci/security/standards-compliance/action.yml` (line 13)
- Modify: `actions/cd/release/registry-publish/action.yml` (line 172)

- [ ] **Step 1: Update standards-compliance action**

In `actions/ci/security/standards-compliance/action.yml`, line 13:

Old: `uses: ./actions/setup/standard-tooling`
New: `uses: ./actions/shared/setup/standard-tooling`

- [ ] **Step 2: Update registry-publish action**

In `actions/cd/release/registry-publish/action.yml`, line 172:

Old: `uses: wphillipmoore/standard-actions/actions/security/trivy@develop`
New: `uses: wphillipmoore/standard-actions/actions/shared/security/trivy@develop`

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add actions/ci/security/standards-compliance/action.yml actions/cd/release/registry-publish/action.yml
st-commit --type refactor --scope actions --message "update action-to-action refs to new namespace (#440)" --agent claude
```

---

## Task 5: Harmonize input name (registry-publish-command → publish-command)

**Files:**
- Modify: `.github/workflows/cd-release.yml` (lines 26-29, 138)

- [ ] **Step 1: Rename the workflow input**

In `.github/workflows/cd-release.yml`, line 26:

Old:
```yaml
      registry-publish-command:
        description: Override ecosystem-derived publish command.
        type: string
        default: ""
```

New:
```yaml
      publish-command:
        description: Override ecosystem-derived publish command.
        type: string
        default: ""
```

- [ ] **Step 2: Update the `with:` mapping**

In `.github/workflows/cd-release.yml`, line 138:

Old: `publish-command: ${{ inputs.registry-publish-command }}`
New: `publish-command: ${{ inputs.publish-command }}`

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add .github/workflows/cd-release.yml
st-commit --type refactor --scope cd-release --message "rename registry-publish-command input to publish-command (#440)" --agent claude
```

---

## Task 6: Verify freeze-internal-refs handles new paths

**Files:**
- Read: `actions/local/freeze-internal-refs/action.yml`

No changes expected — the sed pattern `\./actions/([^[:space:]]+)`
already handles arbitrary path depth. This task confirms that.

- [ ] **Step 1: Inspect the sed pattern**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

grep -n 'sed\|grep.*actions' actions/local/freeze-internal-refs/action.yml
```

Confirm the pattern is `\./actions/([^[:space:]]+)` — this captures
everything after `./actions/` up to whitespace, regardless of depth.
Paths like `./actions/ci/security/codeql` will match.

- [ ] **Step 2: Verify the validation grep**

The action also validates no unfrozen refs remain (line 50):
```
grep -nE 'uses:\s+\./actions/' "$f"
```

This pattern is also depth-agnostic. No changes needed.

- [ ] **Step 3: Spot-check with a dry run**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

echo 'uses: ./actions/ci/security/codeql' | sed -E "s|\./actions/([^[:space:]]+)|wphillipmoore/standard-actions/actions/\1@v1.5.22|g"
```

Expected output:
```
uses: wphillipmoore/standard-actions/actions/ci/security/codeql@v1.5.22
```

No commit needed — this is a verification-only task.

---

## Task 7: Verify no stale references remain

- [ ] **Step 1: Search for any remaining old action paths**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

grep -rn "actions/standards-compliance\|actions/security/codeql\|actions/security/semgrep\|actions/security/trivy\|actions/release-gates\|actions/publish/\|actions/docs-deploy\|actions/setup/standard-tooling\|actions/python/setup" .github/workflows/ actions/ --include="*.yml"
```

Expected: no output. All old paths should be gone.

- [ ] **Step 2: Verify all new paths resolve to existing files**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

grep -roh "uses: \./actions/[^[:space:]]*" .github/workflows/ actions/ --include="*.yml" | sed 's/uses: \.//' | sort -u | while read path; do
  if [ ! -f "${path}/action.yml" ]; then
    echo "BROKEN: ${path}/action.yml does not exist"
  fi
done
```

Expected: no output (all paths resolve).

- [ ] **Step 3: Verify remote refs point to valid paths**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

grep -roh "uses: wphillipmoore/standard-actions/actions/[^@]*" .github/workflows/ actions/ --include="*.yml" | sed 's|uses: wphillipmoore/standard-actions/||' | sort -u | while read path; do
  if [ ! -f "${path}/action.yml" ]; then
    echo "BROKEN: ${path}/action.yml does not exist"
  fi
done
```

Expected: no output.

No commit needed — verification only.

---

## Task 8: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Replace the Composite Actions listing**

In `CLAUDE.md`, replace the `### Composite Actions` section with:

```markdown
### Composite Actions

All actions live under `actions/` organized by pipeline phase:

**Convention:** The `actions/` directory mirrors the workflow namespace.
To find an action, take the workflow filename (e.g., `ci-security.yml`),
split on the first `-` to get phase and domain (`ci` / `security`), and
look in `actions/{phase}/{domain}/`. Cross-phase actions live in
`actions/shared/`. Repo-local actions live in `actions/local/`.

- `actions/ci/security/standards-compliance` — PR-specific compliance
  checks: issue linkage and auto-close keyword rejection
- `actions/ci/security/codeql` — CodeQL static analysis
- `actions/ci/security/semgrep` — Semgrep SAST scanning
- `actions/ci/version-bump/version-divergence` — Pre-merge version
  validation
- `actions/cd/release/validate-inputs` — Pre-flight release input
  validation
- `actions/cd/release/registry-publish` — Build and publish pipeline
  for any supported language ecosystem
- `actions/cd/release/tag-and-release` — Annotated git tags, rolling
  minor tags, and GitHub Releases
- `actions/cd/release/version-bump-pr` — Post-release version bump PRs
- `actions/cd/docs/deploy` — MkDocs Material + mike versioned
  documentation deployment
- `actions/shared/security/trivy` — Trivy vulnerability scanning
  (filesystem, SBOM, container image)
- `actions/shared/setup/standard-tooling` — Installs standard-tooling
  from the version pinned in `standard-tooling.toml`
- `actions/local/freeze-internal-refs` — Freezes relative action refs
  to absolute tagged refs (repo-local)
```

- [ ] **Step 2: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add CLAUDE.md
st-commit --type docs --scope claude --message "update action listing to new namespace (#440)" --agent claude
```

---

## Task 9: Update MkDocs action doc pages

**Files:**
- Rename: 8 files in `docs/site/docs/actions/`
- Delete: `docs/site/docs/actions/python-setup.md`

Each doc page contains `uses:` references with old action paths that
must also be updated.

- [ ] **Step 1: Rename action doc pages**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git mv docs/site/docs/actions/standards-compliance.md            docs/site/docs/actions/ci-security-standards-compliance.md
git mv docs/site/docs/actions/security-codeql.md                 docs/site/docs/actions/ci-security-codeql.md
git mv docs/site/docs/actions/security-semgrep.md                docs/site/docs/actions/ci-security-semgrep.md
git mv docs/site/docs/actions/security-trivy.md                  docs/site/docs/actions/shared-security-trivy.md
git mv docs/site/docs/actions/release-gates-version-divergence.md docs/site/docs/actions/ci-version-bump-version-divergence.md
git mv docs/site/docs/actions/publish-tag-and-release.md         docs/site/docs/actions/cd-release-tag-and-release.md
git mv docs/site/docs/actions/publish-version-bump-pr.md         docs/site/docs/actions/cd-release-version-bump-pr.md
git mv docs/site/docs/actions/docs-deploy.md                     docs/site/docs/actions/cd-docs-deploy.md
```

- [ ] **Step 2: Delete dead doc page**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git rm docs/site/docs/actions/python-setup.md
```

- [ ] **Step 3: Update action path references inside each doc page**

For each renamed doc page, update all `uses:` references to use the
new action paths. The replacements follow the move table from the spec.
Key substitutions:

```
actions/standards-compliance         → actions/ci/security/standards-compliance
actions/security/codeql              → actions/ci/security/codeql
actions/security/semgrep             → actions/ci/security/semgrep
actions/security/trivy               → actions/shared/security/trivy
actions/release-gates/version-divergence → actions/ci/version-bump/version-divergence
actions/publish/tag-and-release      → actions/cd/release/tag-and-release
actions/publish/version-bump-pr      → actions/cd/release/version-bump-pr
actions/docs-deploy                  → actions/cd/docs/deploy
actions/python/setup                 → (delete any references)
```

Apply these inside the doc page content — the `uses:` lines in code
examples and the quick-reference block at the top of each page.

- [ ] **Step 4: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add docs/site/docs/actions/
st-commit --type docs --scope actions --message "rename and update action doc pages for new namespace (#440)" --agent claude
```

---

## Task 10: Update MkDocs cross-cutting doc pages

**Files:**
- Modify: `docs/site/docs/index.md`
- Modify: `docs/site/docs/getting-started.md`
- Modify: `docs/site/docs/configuration.md`
- Modify: `docs/site/docs/ci-gates/security-scanning.md`
- Modify: `docs/site/docs/ci-gates/index.md`
- Modify: `docs/site/docs/development/contributing.md`
- Modify: `docs/site/docs/actions/index.md`

- [ ] **Step 1: Update index.md**

In `docs/site/docs/index.md`, update the action reference table. Replace
old action paths and doc page links with new ones. The table should
reflect the new phase-based groupings rather than the old ad hoc
categories.

- [ ] **Step 2: Update getting-started.md**

In `docs/site/docs/getting-started.md`:
- Line 9: `actions/<action-path>` — update the generic path example
- Line 34: `actions/standards-compliance` →
  `actions/ci/security/standards-compliance`
- Any other old action paths in code examples

- [ ] **Step 3: Update configuration.md**

In `docs/site/docs/configuration.md`:
- Line 54: `publish/version-bump-pr` link →
  `cd-release-version-bump-pr.md`

- [ ] **Step 4: Update ci-gates/security-scanning.md**

In `docs/site/docs/ci-gates/security-scanning.md`:
- Update all action path references and doc page links
- Line 59: `actions/security/codeql` →
  `actions/ci/security/codeql`
- Line 78: `actions/security/semgrep` →
  `actions/ci/security/semgrep`
- Lines 102, 114: `actions/security/trivy` →
  `actions/shared/security/trivy`
- Lines 9-11: update doc page links from `security-*.md` to new names

- [ ] **Step 5: Update ci-gates/index.md**

In `docs/site/docs/ci-gates/index.md`:
- Update any `./actions/` references

- [ ] **Step 6: Update development/contributing.md**

In `docs/site/docs/development/contributing.md`:
- Lines 5-6: update the naming pattern from
  `actions/<category>/<action-name>/action.yml` to
  `actions/{phase}/{domain}/{action}/action.yml`
- Line 10: update script path convention
- Line 12: update local path reference
- Line 13: update docs path convention
- Line 32: `./actions/standards-compliance` →
  `./actions/ci/security/standards-compliance`
- Add guidance on when to use `shared/` vs phase-specific directories

- [ ] **Step 7: Update actions/index.md**

In `docs/site/docs/actions/index.md`:
- Update the description to reference the new convention
- Update any path references

- [ ] **Step 8: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add docs/site/docs/
st-commit --type docs --scope site --message "update doc cross-references for new action namespace (#440)" --agent claude
```

---

## Task 11: Update mkdocs.yml nav

**Files:**
- Modify: `docs/site/mkdocs.yml` (lines 64-80)

- [ ] **Step 1: Replace the Action Reference nav section**

In `docs/site/mkdocs.yml`, replace lines 64-80 with:

```yaml
  - Action Reference:
      - Overview: actions/index.md
      - CI:
          - ci/security/standards-compliance: actions/ci-security-standards-compliance.md
          - ci/security/codeql: actions/ci-security-codeql.md
          - ci/security/semgrep: actions/ci-security-semgrep.md
          - ci/version-bump/version-divergence: actions/ci-version-bump-version-divergence.md
      - CD:
          - cd/release/tag-and-release: actions/cd-release-tag-and-release.md
          - cd/release/version-bump-pr: actions/cd-release-version-bump-pr.md
          - cd/docs/deploy: actions/cd-docs-deploy.md
      - Shared:
          - shared/security/trivy: actions/shared-security-trivy.md
```

Remove the Python entry (action deleted).

- [ ] **Step 2: Commit**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add docs/site/mkdocs.yml
st-commit --type docs --scope mkdocs --message "update nav entries for new action namespace (#440)" --agent claude
```

---

## Task 12: Run validation

- [ ] **Step 1: Run st-validate**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

st-docker-run -- st-validate
```

Expected: all checks pass. If actionlint or yamllint reports errors,
fix them before proceeding.

- [ ] **Step 2: If validation fails, fix and commit**

Fix any issues found, commit with:

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git add <fixed-files>
st-commit --type fix --scope validation --message "fix validation errors from namespace restructure (#440)" --agent claude
```

---

## Task 13: Final verification and PR

- [ ] **Step 1: Run the stale reference check from Task 7**

Repeat the three verification commands from Task 7 to confirm no old
paths remain and all new paths resolve.

- [ ] **Step 2: Review the full diff**

```bash
cd /Users/pmoore/dev/github/standard-actions/.worktrees/issue-440-rationalize-namespace

git diff develop --stat
```

Verify the change count is reasonable: ~12 action moves, ~10 workflow
updates, ~10 doc page updates, CLAUDE.md, mkdocs.yml.

- [ ] **Step 3: Push and create PR**

Push the branch and create a PR targeting `develop`. The PR body should
summarize the namespace convention, list the move table, and note the
one consumer-facing change (`registry-publish-command` →
`publish-command`).
