# Docker CI Centralization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure hadolint runs centrally via st-validate for any repo with Dockerfiles, fix standard-tooling-docker's bespoke CI to use managed container tooling instead of downloading hadolint, and close the superseded issue #378.

**Architecture:** Three small, independent changes across two repos plus issue housekeeping. st-validate already integrates hadolint — just verify it. standard-tooling-docker's CI jobs switch from bare ubuntu + curl to the dev-base container where hadolint is pre-installed. No new actions or workflows in standard-actions.

**Tech Stack:** GitHub Actions workflows (YAML), Python (st-validate), shell

---

### Task 1: Verify st-validate hadolint integration

**Repo:** standard-tooling (`/Users/pmoore/dev/github/standard-tooling/`)

**Purpose:** Confirm the existing hadolint integration in `validate_common.py` works correctly. No code changes expected — this is a verification task.

**Files:**
- Read: `src/standard_tooling/bin/validate_common.py:63-69` (Dockerfile discovery)
- Read: `src/standard_tooling/bin/validate_common.py:145-153` (hadolint execution)
- Read: `tests/standard_tooling/test_validate_common.py:556-598` (hadolint tests)

- [ ] **Step 1: Review the hadolint discovery and execution code**

Read `src/standard_tooling/bin/validate_common.py`. Confirm:
1. `_find_dockerfiles()` (lines 63-69) discovers `Dockerfile*` files at the repo root
2. The main function (lines 145-153) calls `hadolint` with no `--config` flag (correct — repos provide their own `.hadolint.yaml` which hadolint auto-discovers)
3. Non-zero exit codes propagate as failures

- [ ] **Step 2: Run the existing hadolint tests**

```bash
cd /Users/pmoore/dev/github/standard-tooling && st-docker-run -- python -m pytest tests/standard_tooling/test_validate_common.py -k hadolint -v
```

Expected: Both `test_main_hadolint_runs` and `test_main_hadolint_fails` pass. These tests verify:
- hadolint is invoked when Dockerfiles are found
- hadolint failures propagate correctly

- [ ] **Step 3: Verify hadolint runs against real Dockerfiles (manual smoke test)**

Create a temporary Dockerfile at the repo root to confirm st-validate picks it up:

```bash
cd /Users/pmoore/dev/github/standard-tooling
echo 'FROM ubuntu:latest' > Dockerfile.test
st-docker-run -- st-validate 2>&1 | grep -i hadolint
rm Dockerfile.test
```

Expected: Output includes `Running: hadolint (1 files)`. The `FROM ubuntu:latest` line may trigger DL3007 (use a specific image version tag) — that's expected and confirms hadolint is actually executing.

---

### Task 2: Fix standard-tooling-docker ci.yml hadolint job

**Repo:** standard-tooling-docker (`/Users/pmoore/dev/github/standard-tooling-docker/`)

**Purpose:** Replace the bespoke hadolint binary download with the pre-installed hadolint in the dev-base container.

**Files:**
- Modify: `.github/workflows/ci.yml:34-51`

- [ ] **Step 1: Create a feature branch**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
git checkout develop && git pull
git checkout -b feature/378-use-container-hadolint
```

- [ ] **Step 2: Update the hadolint job in ci.yml**

Replace the hadolint job (lines 34-51) with:

```yaml
  hadolint:
    name: "quality / hadolint"
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/wphillipmoore/dev-base:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Generate Dockerfiles from templates
        run: docker/generate.sh

      - name: Run Hadolint
        run: hadolint docker/*/Dockerfile
```

Changes from the original:
- Added `container.image: ghcr.io/wphillipmoore/dev-base:latest`
- Removed the "Download Hadolint" step entirely (hadolint is pre-installed in dev-base at v2.14.0)
- All other steps unchanged

- [ ] **Step 3: Validate the workflow YAML syntax**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
st-docker-run -- actionlint .github/workflows/ci.yml
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
git add .github/workflows/ci.yml
git commit -m "fix(ci): use dev-base container for hadolint instead of downloading binary

Closes #378 (standard-actions). Hadolint is pre-installed in the
dev-base container image — no need to download it separately."
```

---

### Task 3: Fix standard-tooling-docker docker-publish.yml hadolint job

**Repo:** standard-tooling-docker (`/Users/pmoore/dev/github/standard-tooling-docker/`)

**Purpose:** Same change as Task 2 but for the publish workflow. This hadolint job gates the build-scan-push matrix.

**Files:**
- Modify: `.github/workflows/docker-publish.yml:22-39`

- [ ] **Step 1: Update the hadolint job in docker-publish.yml**

Replace the hadolint job (lines 22-39) with:

```yaml
  hadolint:
    name: Lint Dockerfiles
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/wphillipmoore/dev-base:latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Generate Dockerfiles from templates
        run: docker/generate.sh

      - name: Run Hadolint
        run: hadolint docker/*/Dockerfile
```

Changes from the original:
- Added `container.image: ghcr.io/wphillipmoore/dev-base:latest`
- Removed the "Download Hadolint" step entirely
- All other steps unchanged
- The `needs: [hadolint]` dependency on downstream jobs is unaffected

- [ ] **Step 2: Validate the workflow YAML syntax**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
st-docker-run -- actionlint .github/workflows/docker-publish.yml
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
git add .github/workflows/docker-publish.yml
git commit -m "fix(ci): use dev-base container for hadolint in publish workflow

Same change as ci.yml — use the pre-installed hadolint from the
dev-base container instead of downloading the binary."
```

---

### Task 4: Push and verify CI (standard-tooling-docker)

**Repo:** standard-tooling-docker (`/Users/pmoore/dev/github/standard-tooling-docker/`)

**Purpose:** Push the branch, open a PR, and verify the hadolint jobs pass in CI with the container-based approach.

- [ ] **Step 1: Push the branch and open a PR**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
git push -u origin feature/378-use-container-hadolint
gh pr create --title "fix(ci): use dev-base container for hadolint" --body "$(cat <<'EOF'
## Summary

- Switch hadolint CI jobs to run inside the `dev-base` container instead
  of downloading the binary on bare `ubuntu-latest`
- Removes the curl/download step from both `ci.yml` and `docker-publish.yml`
- Hadolint v2.14.0 is already pre-installed in the dev-base container image

Closes wphillipmoore/standard-actions#378

## Test plan

- [ ] `quality / hadolint` job passes in CI (ci.yml)
- [ ] docker-publish.yml hadolint job passes (triggered on merge)
- [ ] Downstream jobs that depend on hadolint (`needs: [hadolint]`) still run
EOF
)"
```

- [ ] **Step 2: Monitor CI and confirm hadolint jobs pass**

```bash
cd /Users/pmoore/dev/github/standard-tooling-docker
gh pr checks --watch
```

Expected: The `quality / hadolint` job passes using the dev-base container.

---

### Task 5: Close issue #378 on standard-actions

**Repo:** standard-actions (`/Users/pmoore/dev/github/standard-actions/`)

**Purpose:** Close the original issue with a comment explaining the revised outcome.

- [ ] **Step 1: Add a comment and close the issue**

```bash
gh issue comment 378 --body "$(cat <<'EOF'
## Resolution

Through design analysis, the original goal — reusable Docker CI
workflows/composite actions in standard-actions — turned out not to be
needed:

1. **Hadolint is already integrated in st-validate** (`validate_common.py`
   auto-detects Dockerfiles and runs hadolint). Any repo running
   `st-validate` via `ci-quality.yml` gets hadolint for free.

2. **No centralized hadolint config needed.** Hadolint's defaults are the
   right fleet-wide defaults. Repos needing exceptions provide their own
   `.hadolint.yaml` (auto-discovered by hadolint natively).

3. **standard-tooling-docker's bespoke CI fixed** to use the dev-base
   container (where hadolint is pre-installed) instead of downloading the
   binary. See the linked PR.

Design spec: `docs/specs/2026-05-08-docker-ci-centralization-design.md`
EOF
)"

gh issue close 378
```

---

### Task 6: Commit spec and plan to standard-actions

**Repo:** standard-actions (`/Users/pmoore/dev/github/standard-actions/`)

**Purpose:** Commit the design spec and implementation plan created during this session.

- [ ] **Step 1: Commit the docs**

```bash
cd /Users/pmoore/dev/github/standard-actions
git add docs/specs/2026-05-08-docker-ci-centralization-design.md
git add docs/plans/2026-05-08-docker-ci-centralization.md
git commit -m "docs: add design spec and plan for Docker CI centralization (#378)"
```
