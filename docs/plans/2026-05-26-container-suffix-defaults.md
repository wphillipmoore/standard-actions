# Container-Suffix Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix container-suffix inline fallbacks so language repos
don't need explicit overrides, and make the `language` input optional
so non-language repos don't need to pass fake values.

**Architecture:** Six reusable workflow files get their `language`
input changed from `required: true` to `required: false`, with
updated descriptions. Two workflows (ci-audit, ci-test) have their
inline container fallback changed from `|| 'base'` to
`|| inputs.language`. One workflow (ci-quality) gets `if` guards on
language-specific jobs. One workflow (ci-security) gets an additional
`if` condition on CodeQL. One workflow (cd-release) gets its
`language` default changed and a fallback added, plus a
validate-inputs action update. Finally, the local `ci.yml` caller
is cleaned up as the first consuming-repo proof.

**Tech Stack:** GitHub Actions reusable workflows (YAML),
composite actions (YAML + shell)

**Spec:** `docs/specs/2026-05-26-container-suffix-defaults-design.md`
**Issue:** #560

---

### Task 1: Fix ci-audit.yml

**Files:**
- Modify: `.github/workflows/ci-audit.yml:6-18,37`

- [ ] **Step 1: Change language input to optional and update description**

Replace lines 6-18:

```yaml
      language:
        type: string
        required: true
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Container image name suffix (e.g. python, go, base). Defaults
          to "base". Callers should pass their language-specific suffix
          (e.g. "python", "go") when needed.
```

With:

```yaml
      language:
        type: string
        required: false
        description: >-
          Primary language (e.g. python, go, java, ruby, rust). Drives
          container image selection. Omit for non-language repos.
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Override the container image name suffix. Defaults to the
          language input when provided.
```

- [ ] **Step 2: Change inline fallback from 'base' to inputs.language**

Replace line 37:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.container-suffix || 'base' }}:${{ matrix.version }}
```

With:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.container-suffix || inputs.language }}:${{ matrix.version }}
```

- [ ] **Step 3: Run validation**

Run from the worktree:

```bash
vrg-container-run -- vrg-validate
```

Expected: passes (YAML is valid, actionlint accepts the expression).

- [ ] **Step 4: Commit**

```bash
vrg-git add .github/workflows/ci-audit.yml
vrg-commit --type fix --scope ci \
  --message "default container-suffix to language in ci-audit" \
  --body "Change language input to optional and revert inline fallback
from 'base' to inputs.language so language repos no longer need
explicit container-suffix overrides. Ref #560"
```

---

### Task 2: Fix ci-test.yml

**Files:**
- Modify: `.github/workflows/ci-test.yml:6-18,37`

- [ ] **Step 1: Change language input to optional and update description**

Replace lines 6-18:

```yaml
      language:
        type: string
        required: true
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Container image name suffix (e.g. python, go, base). Defaults
          to "base". Callers should pass their language-specific suffix
          (e.g. "python", "go") when needed.
```

With:

```yaml
      language:
        type: string
        required: false
        description: >-
          Primary language (e.g. python, go, java, ruby, rust). Drives
          container image selection. Omit for non-language repos.
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Override the container image name suffix. Defaults to the
          language input when provided.
```

- [ ] **Step 2: Change inline fallback from 'base' to inputs.language**

Replace line 37:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.container-suffix || 'base' }}:${{ matrix.version }}
```

With:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.container-suffix || inputs.language }}:${{ matrix.version }}
```

- [ ] **Step 3: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 4: Commit**

```bash
vrg-git add .github/workflows/ci-test.yml
vrg-commit --type fix --scope ci \
  --message "default container-suffix to language in ci-test" \
  --body "Same change as ci-audit: language input optional, inline
fallback reverted from 'base' to inputs.language. Ref #560"
```

---

### Task 3: Update ci-quality.yml

**Files:**
- Modify: `.github/workflows/ci-quality.yml:6-18,47,68`

- [ ] **Step 1: Change language input to optional and update description**

Replace lines 6-18:

```yaml
      language:
        type: string
        required: true
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Container image name suffix (e.g. python, go, base). Defaults
          to the language input. Callers whose language is "shell" or
          "none" should pass "base".
```

With:

```yaml
      language:
        type: string
        required: false
        description: >-
          Primary language (e.g. python, go, java, ruby, rust). Drives
          container image selection for lint and typecheck jobs. Omit
          for non-language repos — lint and typecheck will be skipped.
      versions:
        type: string
        required: true
      container-suffix:
        type: string
        required: false
        description: >-
          Override the container image name suffix. Defaults to "base"
          for the common job; defaults to the language input for lint
          and typecheck jobs.
```

- [ ] **Step 2: Add if guard to lint job**

Add an `if:` condition to the lint job. Insert after line 48
(`runs-on: ubuntu-latest`), before `container:`:

Change:

```yaml
  lint:
    name: lint / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/vergil-project/...
```

To:

```yaml
  lint:
    name: lint / ${{ matrix.version }}
    if: inputs.language != ''
    runs-on: ubuntu-latest
    container: ghcr.io/vergil-project/...
```

- [ ] **Step 3: Add if guard to typecheck job**

Same change for typecheck. Insert after line 69
(`runs-on: ubuntu-latest`), before `container:`:

Change:

```yaml
  typecheck:
    name: typecheck / ${{ matrix.version }}
    runs-on: ubuntu-latest
    container: ghcr.io/vergil-project/...
```

To:

```yaml
  typecheck:
    name: typecheck / ${{ matrix.version }}
    if: inputs.language != ''
    runs-on: ubuntu-latest
    container: ghcr.io/vergil-project/...
```

- [ ] **Step 4: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 5: Commit**

```bash
vrg-git add .github/workflows/ci-quality.yml
vrg-commit --type fix --scope ci \
  --message "make language optional in ci-quality, skip lint/typecheck when absent" \
  --body "Language input is now optional. Lint and typecheck jobs are
skipped when language is not provided. Common job continues to run
against the base image. Ref #560"
```

---

### Task 4: Update ci-security.yml

**Files:**
- Modify: `.github/workflows/ci-security.yml:6-9,65`

- [ ] **Step 1: Change language input to optional and update description**

Replace lines 6-9:

```yaml
      language:
        description: Language for security scanners (e.g., ruby, python, go, java)
        type: string
        required: true
```

With:

```yaml
      language:
        description: >-
          Primary language (e.g. python, go, java, ruby, rust). Used
          by CodeQL and Semgrep for language-specific rulesets. Omit
          for non-language repos — CodeQL will be skipped
          automatically.
        type: string
        required: false
```

- [ ] **Step 2: Add language guard to CodeQL job condition**

Replace line 65:

```yaml
    if: ${{ inputs.run-security && inputs.run-codeql }}
```

With:

```yaml
    if: ${{ inputs.run-security && inputs.run-codeql && inputs.language != '' }}
```

- [ ] **Step 3: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 4: Commit**

```bash
vrg-git add .github/workflows/ci-security.yml
vrg-commit --type fix --scope ci \
  --message "make language optional in ci-security, auto-skip CodeQL when absent" \
  --body "Language input is now optional. CodeQL is automatically
skipped when language is not provided, so callers no longer need
to pass run-codeql: false. Ref #560"
```

---

### Task 5: Update ci-version-bump.yml

**Files:**
- Modify: `.github/workflows/ci-version-bump.yml:6-8`

- [ ] **Step 1: Change language input to optional and update description**

Replace lines 6-8:

```yaml
      language:
        type: string
        required: true
```

With:

```yaml
      language:
        type: string
        required: false
        description: >-
          Primary language. Accepted for interface consistency with
          other CI workflows; not used by the version-bump job.
```

- [ ] **Step 2: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 3: Commit**

```bash
vrg-git add .github/workflows/ci-version-bump.yml
vrg-commit --type fix --scope ci \
  --message "make language optional in ci-version-bump" \
  --body "Language input is now optional. The version-bump job uses
the base container regardless. Ref #560"
```

---

### Task 6: Update cd-release.yml and validate-inputs action

**Files:**
- Modify: `.github/workflows/cd-release.yml:7-9,64`
- Modify: `actions/cd/release/validate-inputs/action.yml:29-33,35-39`

- [ ] **Step 1: Change language default from "base" to empty string**

Replace lines 7-9 in `cd-release.yml`:

```yaml
      language:
        description: Primary language (matches container image suffix).
        type: string
        default: "base"
```

With:

```yaml
      language:
        description: >-
          Primary language (e.g. python, go, java, ruby, rust). Drives
          container image selection and build/publish commands. Omit
          for non-language repos.
        type: string
        default: ""
```

- [ ] **Step 2: Add fallback to container expression**

Replace line 64 in `cd-release.yml`:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.language }}:${{ inputs.container-tag }}
```

With:

```yaml
    container: ghcr.io/vergil-project/${{ inputs.container-prefix || 'prod' }}-${{ inputs.language || 'base' }}:${{ inputs.container-tag }}
```

- [ ] **Step 3: Update validate-inputs to accept empty language**

In `actions/cd/release/validate-inputs/action.yml`, replace the
container-tag guard (lines 29-33):

```bash
        if [ "$INPUT_LANGUAGE" != "base" ] && \
           [ "$INPUT_CONTAINER_TAG" = "latest" ]; then
          echo "::error::language '${INPUT_LANGUAGE}' requires an explicit container-tag (language-specific images do not publish a :latest tag)"
          exit 1
        fi
```

With:

```bash
        if [ "$INPUT_LANGUAGE" != "base" ] && \
           [ -n "$INPUT_LANGUAGE" ] && \
           [ "$INPUT_CONTAINER_TAG" = "latest" ]; then
          echo "::error::language '${INPUT_LANGUAGE}' requires an explicit container-tag (language-specific images do not publish a :latest tag)"
          exit 1
        fi
```

Then replace the registry-publish guard (lines 35-39):

```bash
        if [ "$INPUT_REGISTRY_PUBLISH" = "true" ] && \
           [ "$INPUT_LANGUAGE" = "base" ]; then
          echo "::error::registry-publish requires a language to derive ecosystem build/publish commands"
          exit 1
        fi
```

With:

```bash
        if [ "$INPUT_REGISTRY_PUBLISH" = "true" ] && \
           { [ "$INPUT_LANGUAGE" = "base" ] || [ -z "$INPUT_LANGUAGE" ]; }; then
          echo "::error::registry-publish requires a language to derive ecosystem build/publish commands"
          exit 1
        fi
```

- [ ] **Step 4: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 5: Commit**

```bash
vrg-git add .github/workflows/cd-release.yml \
  actions/cd/release/validate-inputs/action.yml
vrg-commit --type fix --scope cd \
  --message "make language optional in cd-release, update validate-inputs" \
  --body "Language default changed from 'base' to empty string.
Container expression now falls back to 'base' when language is
omitted. validate-inputs treats empty language the same as 'base'
for container-tag and registry-publish guards. Ref #560"
```

---

### Task 7: Clean up local ci.yml (self-consuming proof)

**Files:**
- Modify: `.github/workflows/ci.yml:15-39`

This repo is a non-language repo (`primary-language = "shell"`).
Apply the consuming-repo cleanup pattern from the spec as the
first proof that the workflow changes are backwards-compatible
for non-language callers.

- [ ] **Step 1: Simplify the quality job**

Replace:

```yaml
  quality:
    uses: ./.github/workflows/ci-quality.yml
    with:
      language: shell
      versions: '["latest"]'
      container-suffix: base
      container-tag: 'latest'
```

With:

```yaml
  quality:
    uses: ./.github/workflows/ci-quality.yml
    with:
      versions: '["latest"]'
```

- [ ] **Step 2: Simplify the security job**

Replace:

```yaml
  security:
    uses: ./.github/workflows/ci-security.yml
    permissions:
      contents: read
      security-events: write
    with:
      language: shell
      run-codeql: false
      container-suffix: base
      container-tag: 'latest'
```

With:

```yaml
  security:
    uses: ./.github/workflows/ci-security.yml
    permissions:
      contents: read
      security-events: write
```

- [ ] **Step 3: Simplify the version job**

Replace:

```yaml
  version:
    uses: ./.github/workflows/ci-version-bump.yml
    with:
      language: shell
      container-suffix: base
      container-tag: 'latest'
```

With:

```yaml
  version:
    uses: ./.github/workflows/ci-version-bump.yml
```

- [ ] **Step 4: Run validation**

```bash
vrg-container-run -- vrg-validate
```

Expected: passes.

- [ ] **Step 5: Commit**

```bash
vrg-git add .github/workflows/ci.yml
vrg-commit --type fix --scope ci \
  --message "remove redundant language and container overrides from local CI" \
  --body "This repo is a non-language repo. With language now optional
and defaults corrected, the local ci.yml no longer needs to pass
language, container-suffix, container-tag, or run-codeql. Ref #560"
```

---

### Task 8: Final validation and branch push

- [ ] **Step 1: Full validation from the worktree**

```bash
vrg-container-run -- vrg-validate
```

Expected: all checks pass.

- [ ] **Step 2: Review the full diff against develop**

```bash
vrg-git diff develop..HEAD --stat
vrg-git log develop..HEAD --oneline
```

Verify: 7 task commits plus the earlier spec and hook-migration
commits. No untracked files.

- [ ] **Step 3: Push branch and open PR**

Use the `/vergil:pr-workflow` skill to push the branch and create
the PR against `develop`. The PR should reference issue #560.
CI will run against the updated local `ci.yml` — this is the
self-test that proves the non-language caller pattern works.
