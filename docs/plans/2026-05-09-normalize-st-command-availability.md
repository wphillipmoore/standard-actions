# Normalize st-* Command Availability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `st-*` command availability for the standard-tooling self-install path by adding a single `GITHUB_PATH` line to the setup action, then remove all per-call-site PATH workarounds that are no longer needed.

**Architecture:** The `setup/standard-tooling` action's self-install branch runs `uv sync --frozen --group dev`, which installs into `.venv/bin/` (not on PATH). We add one line — `echo "$GITHUB_WORKSPACE/.venv/bin" >> "$GITHUB_PATH"` — to register that directory with the runner's inter-step PATH mechanism. This makes `st-*` commands available to all subsequent steps without per-step workarounds. Then we clean up the 5 files that carry those workarounds.

**Tech Stack:** GitHub Actions YAML (composite actions and reusable workflows)

---

### Task 1: Add GITHUB_PATH to the setup action

**Files:**
- Modify: `actions/setup/standard-tooling/action.yml:18-21`

- [ ] **Step 1: Add the GITHUB_PATH line**

In `actions/setup/standard-tooling/action.yml`, add `echo "$GITHUB_WORKSPACE/.venv/bin" >> "$GITHUB_PATH"` after the `uv sync` line in the self-install branch. The full `run:` block becomes:

```yaml
    - name: Install standard-tooling
      shell: bash
      run: |
        if grep -q '^name = "standard-tooling"' pyproject.toml 2>/dev/null; then
          echo "Consumer repo is standard-tooling itself — installing from source"
          uv sync --frozen --group dev
          echo "$GITHUB_WORKSPACE/.venv/bin" >> "$GITHUB_PATH"
          exit 0
        fi

        TAG=$(sed -n 's/^[[:space:]]*standard-tooling[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' standard-tooling.toml)
        if [ -z "${TAG:-}" ]; then
          echo "::error::standard-tooling.toml not found or missing version tag"
          exit 1
        fi
        uv tool install "standard-tooling @ git+https://github.com/wphillipmoore/standard-tooling@${TAG}"
```

- [ ] **Step 2: Validate the setup action**

Run: `st-docker-run -- st-validate`

Expected: PASS — the new line is valid YAML and valid shell.

- [ ] **Step 3: Commit**

```bash
git add actions/setup/standard-tooling/action.yml
git commit -m "fix: add GITHUB_PATH for st-* commands in self-install path

Ref #403"
```

---

### Task 2: Remove PATH workaround from ci-audit.yml

**Files:**
- Modify: `.github/workflows/ci-audit.yml:1-6,48`

- [ ] **Step 1: Remove the 6-line comment block**

Delete lines 1–6 (the `# PATH workaround (#362): ...` comment block) from the top of `.github/workflows/ci-audit.yml`:

```yaml
# PATH workaround (#362): GitHub Actions overrides the container WORKDIR to
# /__w/<repo>/<repo>, so the Docker image's /workspace/.venv/bin PATH entry
# never resolves.  Each st-validate step prepends $GITHUB_WORKSPACE/.venv/bin
# to PATH so that st-validate itself (standard-tooling self-install case) and
# dev tools it invokes (ruff, mypy, pytest, pip-audit) are findable.  This is
# a harmless no-op for non-Python repos where .venv does not exist.
```

- [ ] **Step 2: Remove the PATH line from the run step**

In the `Run dependency audit` step, change the `run:` block from:

```yaml
      - name: Run dependency audit
        run: |
          PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
          st-validate --check audit
```

to:

```yaml
      - name: Run dependency audit
        run: st-validate --check audit
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci-audit.yml
git commit -m "refactor: remove PATH workaround from ci-audit.yml

The setup/standard-tooling action now handles this via GITHUB_PATH.

Ref #403"
```

---

### Task 3: Remove PATH workarounds from ci-quality.yml

**Files:**
- Modify: `.github/workflows/ci-quality.yml:1-6,47,70,93`

- [ ] **Step 1: Remove the 6-line comment block**

Delete lines 1–6 (the same `# PATH workaround (#362): ...` comment block) from the top of `.github/workflows/ci-quality.yml`.

- [ ] **Step 2: Remove the PATH line from the common job**

In the `Run common quality checks` step, change:

```yaml
      - name: Run common quality checks
        run: |
          PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
          st-validate --check common
```

to:

```yaml
      - name: Run common quality checks
        run: st-validate --check common
```

- [ ] **Step 3: Remove the PATH line from the lint job**

In the `Run lint` step, change:

```yaml
      - name: Run lint
        run: |
          PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
          st-validate --check lint
```

to:

```yaml
      - name: Run lint
        run: st-validate --check lint
```

- [ ] **Step 4: Remove the PATH line from the typecheck job**

In the `Run typecheck` step, change:

```yaml
      - name: Run typecheck
        run: |
          PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
          st-validate --check typecheck
```

to:

```yaml
      - name: Run typecheck
        run: st-validate --check typecheck
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci-quality.yml
git commit -m "refactor: remove PATH workarounds from ci-quality.yml

Removes the comment block and three per-step PATH lines (common,
lint, typecheck). The setup/standard-tooling action now handles
this via GITHUB_PATH.

Ref #403"
```

---

### Task 4: Remove PATH workaround from ci-test.yml

**Files:**
- Modify: `.github/workflows/ci-test.yml:1-6,48`

- [ ] **Step 1: Remove the 6-line comment block**

Delete lines 1–6 (the `# PATH workaround (#362): ...` comment block) from the top of `.github/workflows/ci-test.yml`.

- [ ] **Step 2: Remove the PATH line from the run step**

In the `Run unit tests` step, change:

```yaml
      - name: Run unit tests
        run: |
          PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
          st-validate --check test
```

to:

```yaml
      - name: Run unit tests
        run: st-validate --check test
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci-test.yml
git commit -m "refactor: remove PATH workaround from ci-test.yml

The setup/standard-tooling action now handles this via GITHUB_PATH.

Ref #403"
```

---

### Task 5: Remove PATH workaround from standards-compliance action

**Files:**
- Modify: `actions/standards-compliance/action.yml:19`

- [ ] **Step 1: Remove the PATH line**

In the `Validate pull request issue linkage` step, change:

```yaml
    - name: Validate pull request issue linkage
      if: github.event_name == 'pull_request'
      shell: bash
      run: |
        PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
        st-pr-issue-linkage
```

to:

```yaml
    - name: Validate pull request issue linkage
      if: github.event_name == 'pull_request'
      shell: bash
      run: st-pr-issue-linkage
```

- [ ] **Step 2: Commit**

```bash
git add actions/standards-compliance/action.yml
git commit -m "refactor: remove PATH workaround from standards-compliance action

The setup/standard-tooling action now handles this via GITHUB_PATH.

Ref #403"
```

---

### Task 6: Remove PATH workaround from version-divergence action

**Files:**
- Modify: `actions/release-gates/version-divergence/action.yml:42`

- [ ] **Step 1: Remove the PATH line**

In the `Compare versions` step, change:

```yaml
    - name: Compare versions
      id: compare
      shell: bash
      run: |
        PATH="$GITHUB_WORKSPACE/.venv/bin:$PATH"
        head_version=$(${{ inputs.head-version-command }})
```

to:

```yaml
    - name: Compare versions
      id: compare
      shell: bash
      run: |
        head_version=$(${{ inputs.head-version-command }})
```

Note: this step keeps its `run: |` block because it has multiple lines of shell logic beyond the PATH line.

- [ ] **Step 2: Commit**

```bash
git add actions/release-gates/version-divergence/action.yml
git commit -m "refactor: remove PATH workaround from version-divergence action

The setup/standard-tooling action now handles this via GITHUB_PATH.

Ref #403"
```

---

### Task 7: Final validation

- [ ] **Step 1: Run full validation**

Run: `st-docker-run -- st-validate`

Expected: PASS — all YAML linting, actionlint, shellcheck, and markdownlint checks pass.

- [ ] **Step 2: Review the full diff**

Run: `git diff HEAD~6 --stat` to confirm the change footprint matches the spec:
- 1 file with a line added (`actions/setup/standard-tooling/action.yml`)
- 5 files with lines removed (3 workflow files + 2 composite actions)
- No other files modified
