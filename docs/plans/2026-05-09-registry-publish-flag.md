# Registry Publish Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `registry-publish` boolean input to `publish-release.yml` that gates all registry-specific steps, make `language` and `container-tag` optional with defaults, and update all 11 fleet callers.

**Architecture:** The reusable workflow gains one new boolean input (`registry-publish`, default `false`) and a validation step that catches invalid input combinations early. Nine existing steps are gated behind this flag. `language` and `container-tag` become optional with defaults (`base`/`latest`) so non-language repos can omit them. Fleet callers are updated to pass the appropriate inputs.

**Tech Stack:** GitHub Actions reusable workflows (YAML), `st-validate` for validation.

---

## Context

### Current state

`publish-release.yml` has two required inputs (`language`, `container-tag`). Registry-specific steps run unconditionally (or are skipped only incidentally when derived commands are empty). Only `standard-tooling` passes `language: python`; the other 10 callers pass no `with:` inputs.

### Spec

`docs/specs/2026-05-09-registry-publish-flag-design.md`

### Issues

- [#411](https://github.com/wphillipmoore/standard-actions/issues/411) — make PyPI publishing opt-in
- [#412](https://github.com/wphillipmoore/standard-actions/issues/412) — add registry-publish flag and update fleet

---

## Task 1: Modify inputs and add validation step in publish-release.yml

**Files:**
- Modify: `.github/workflows/publish-release.yml:4-58` (inputs section)
- Modify: `.github/workflows/publish-release.yml:77-84` (insert validation step after checkout)

- [ ] **Step 1: Change `language` from required to optional with default**

In `.github/workflows/publish-release.yml`, replace:

```yaml
      language:
        description: Primary language (matches dev container image suffix).
        type: string
        required: true
```

with:

```yaml
      language:
        description: Primary language (matches dev container image suffix).
        type: string
        default: "base"
```

- [ ] **Step 2: Change `container-tag` from required to optional with default**

Replace:

```yaml
      container-tag:
        description: Dev container image tag (e.g. 3.14, 1.26).
        type: string
        required: true
```

with:

```yaml
      container-tag:
        description: Dev container image tag (e.g. 3.14, 1.26).
        type: string
        default: "latest"
```

- [ ] **Step 3: Add `registry-publish` input**

Add after the `container-tag` input block:

```yaml
      registry-publish:
        description: Publish build artifacts to an external package registry.
        type: boolean
        default: false
```

- [ ] **Step 4: Add the input validation step**

Insert a new step immediately after "Checkout code" (after line 81) and before "Install standard-tooling":

```yaml
      - name: Validate inputs
        run: |
          if [ "${{ inputs.language }}" != "base" ] && \
             [ "${{ inputs.container-tag }}" = "latest" ]; then
            echo "::error::language '${{ inputs.language }}' requires an explicit container-tag (language-specific images do not publish a :latest tag)"
            exit 1
          fi
          if [ "${{ inputs.registry-publish }}" = "true" ] && \
             [ "${{ inputs.language }}" = "base" ]; then
            echo "::error::registry-publish requires a language to derive ecosystem build/publish commands"
            exit 1
          fi
```

- [ ] **Step 5: Run validation**

```bash
st-docker-run -- st-validate
```

Expected: all checks pass.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/publish-release.yml
```

```bash
git commit -m "$(cat <<'EOF'
fix(publish): make language/container-tag optional, add registry-publish input

language defaults to base and container-tag defaults to latest so
non-language repos can omit them. A new registry-publish boolean input
(default false) is added for use in the next commit. Input validation
catches invalid combinations: language-specific images with latest tag,
and registry-publish without a language. Ref #411, #412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Gate registry-specific steps behind `registry-publish`

**Files:**
- Modify: `.github/workflows/publish-release.yml` (conditional steps throughout)

All changes in this task prepend `inputs.registry-publish &&` to existing `if` conditions on nine steps.

- [ ] **Step 1: Gate "Configure Maven credentials"**

Replace:

```yaml
      - name: Configure Maven credentials
        if: inputs.language == 'java'
```

with:

```yaml
      - name: Configure Maven credentials
        if: inputs.registry-publish && inputs.language == 'java'
```

- [ ] **Step 2: Gate "Derive ecosystem commands"**

Replace:

```yaml
      - name: Derive ecosystem commands
        if: steps.tag_check.outputs.exists == 'false'
```

with:

```yaml
      - name: Derive ecosystem commands
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 3: Gate "Prepare version-dependent inputs"**

Replace:

```yaml
      - name: Prepare version-dependent inputs
        if: steps.tag_check.outputs.exists == 'false'
```

with:

```yaml
      - name: Prepare version-dependent inputs
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 4: Gate "Ensure dist directory"**

Replace:

```yaml
      - name: Ensure dist directory
        if: steps.tag_check.outputs.exists == 'false'
```

with:

```yaml
      - name: Ensure dist directory
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 5: Gate "Build"**

Replace:

```yaml
      - name: Build
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          steps.commands.outputs.build != ''
```

with:

```yaml
      - name: Build
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          steps.commands.outputs.build != ''
```

- [ ] **Step 6: Gate "Attest build provenance"**

Replace:

```yaml
      - name: Attest build provenance
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          inputs.attestation-subject-path != ''
```

with:

```yaml
      - name: Attest build provenance
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          inputs.attestation-subject-path != ''
```

- [ ] **Step 7: Gate "Generate SBOM"**

Replace:

```yaml
      - name: Generate SBOM
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          inputs.sbom-output-file != ''
```

with:

```yaml
      - name: Generate SBOM
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          inputs.sbom-output-file != ''
```

- [ ] **Step 8: Gate "Publish to PyPI"**

Replace:

```yaml
      - name: Publish to PyPI
        if: >-
          inputs.language == 'python' &&
          steps.tag_check.outputs.exists == 'false'
```

with:

```yaml
      - name: Publish to PyPI
        if: >-
          inputs.registry-publish &&
          inputs.language == 'python' &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 9: Gate "Publish to registry"**

Replace:

```yaml
      - name: Publish to registry
        if: >-
          inputs.language != 'python' &&
          steps.commands.outputs.publish != '' &&
          steps.tag_check.outputs.exists == 'false'
```

with:

```yaml
      - name: Publish to registry
        if: >-
          inputs.registry-publish &&
          inputs.language != 'python' &&
          steps.commands.outputs.publish != '' &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 10: Run validation**

```bash
st-docker-run -- st-validate
```

Expected: all checks pass.

- [ ] **Step 11: Commit**

```bash
git add .github/workflows/publish-release.yml
```

```bash
git commit -m "$(cat <<'EOF'
fix(publish): gate registry-specific steps behind registry-publish input

Nine steps that are only meaningful for external registry publication
(Maven creds, ecosystem command derivation, build, attestation, SBOM,
PyPI publish, registry publish, dist directory, version-dependent
inputs) are now gated behind the registry-publish boolean input.
Callers must opt in with registry-publish: true. Ref #411, #412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update fleet callers — publishing repos

These 5 repos publish to an external package registry. Each gets `language`, `container-tag`, and `registry-publish: true`.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-python/.github/workflows/publish-release.yml`
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-go/.github/workflows/publish-release.yml`
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-java/.github/workflows/publish-release.yml`
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-ruby/.github/workflows/publish-release.yml`
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-rust/.github/workflows/publish-release.yml`

All 5 repos currently have identical workflow files with no `with:` block:

```yaml
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

- [ ] **Step 1: Update mq-rest-admin-python**

In `/Users/pmoore/dev/github/mq-rest-admin-python/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: python
      container-tag: "3.14"
      registry-publish: true
    secrets: inherit
```

- [ ] **Step 2: Commit mq-rest-admin-python**

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-python && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-python && git commit -m "$(cat <<'EOF'
fix(ci): specify language, container-tag, and registry-publish in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Update mq-rest-admin-go**

In `/Users/pmoore/dev/github/mq-rest-admin-go/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: go
      container-tag: "1.26"
      registry-publish: true
    secrets: inherit
```

- [ ] **Step 4: Commit mq-rest-admin-go**

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-go && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-go && git commit -m "$(cat <<'EOF'
fix(ci): specify language, container-tag, and registry-publish in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Update mq-rest-admin-java**

In `/Users/pmoore/dev/github/mq-rest-admin-java/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: java
      container-tag: "17"
      registry-publish: true
    secrets: inherit
```

- [ ] **Step 6: Commit mq-rest-admin-java**

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-java && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-java && git commit -m "$(cat <<'EOF'
fix(ci): specify language, container-tag, and registry-publish in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Update mq-rest-admin-ruby**

In `/Users/pmoore/dev/github/mq-rest-admin-ruby/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: ruby
      container-tag: "3.4"
      registry-publish: true
    secrets: inherit
```

- [ ] **Step 8: Commit mq-rest-admin-ruby**

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-ruby && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-ruby && git commit -m "$(cat <<'EOF'
fix(ci): specify language, container-tag, and registry-publish in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Update mq-rest-admin-rust**

In `/Users/pmoore/dev/github/mq-rest-admin-rust/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: rust
      container-tag: "1.93"
      registry-publish: true
    secrets: inherit
```

- [ ] **Step 10: Commit mq-rest-admin-rust**

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-rust && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/mq-rest-admin-rust && git commit -m "$(cat <<'EOF'
fix(ci): specify language, container-tag, and registry-publish in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Update fleet callers — language-only repos

These 2 repos need a Python container for their release pipeline but do not publish to PyPI. They pass `language` and `container-tag` but omit `registry-publish` (defaults to `false`).

**Files:**
- Modify: `/Users/pmoore/dev/github/standard-tooling/.github/workflows/publish-release.yml`
- Modify: `/Users/pmoore/dev/github/ai-research-methodology/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update standard-tooling**

In `/Users/pmoore/dev/github/standard-tooling/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: python
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: python
      container-tag: "3.14"
    secrets: inherit
```

- [ ] **Step 2: Commit standard-tooling**

```bash
cd /Users/pmoore/dev/github/standard-tooling && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/standard-tooling && git commit -m "$(cat <<'EOF'
fix(ci): specify container-tag in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Update ai-research-methodology**

In `/Users/pmoore/dev/github/ai-research-methodology/.github/workflows/publish-release.yml`, replace:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

with:

```yaml
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    with:
      language: python
      container-tag: "3.14"
    secrets: inherit
```

- [ ] **Step 4: Commit ai-research-methodology**

```bash
cd /Users/pmoore/dev/github/ai-research-methodology && git add .github/workflows/publish-release.yml
```

```bash
cd /Users/pmoore/dev/github/ai-research-methodology && git commit -m "$(cat <<'EOF'
fix(ci): specify language and container-tag in publish-release caller

Required by standard-actions #412. Ref wphillipmoore/standard-actions#412

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Verify fleet callers — default repos

These 4 repos don't publish to a registry and don't need a language-specific container. With the new defaults (`language: base`, `container-tag: latest`, `registry-publish: false`), they need no `with:` block. Verify they are correct as-is.

**Files (read-only verification):**
- Verify: `/Users/pmoore/dev/github/standard-tooling-plugin/.github/workflows/publish-release.yml`
- Verify: `/Users/pmoore/dev/github/mq-rest-admin-common/.github/workflows/publish-release.yml`
- Verify: `/Users/pmoore/dev/github/mq-rest-admin-dev-environment/.github/workflows/publish-release.yml`
- Verify: `/Users/pmoore/dev/github/mq-rest-admin-template/.github/workflows/publish-release.yml`

- [ ] **Step 1: Verify all 4 repos have no `with:` block**

For each of the 4 repos, confirm the workflow file contains:

```yaml
jobs:
  publish:
    uses: wphillipmoore/standard-actions/.github/workflows/publish-release.yml@v1.5
    secrets: inherit
```

No changes needed. The defaults (`base`/`latest`/`false`) match their requirements.

---

## Rollout Order

1. **Tasks 1-2** — merge the `publish-release.yml` changes in standard-actions (moves floating `v1.5` tag)
2. **Tasks 3-4** — push fleet caller updates to each repo
3. **Task 5** — verify default repos still work (no code change, just confirmation)

The fleet is frozen — no releases will be triggered during the rollout window.
