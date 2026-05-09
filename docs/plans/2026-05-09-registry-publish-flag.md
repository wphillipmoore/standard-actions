# Registry Publish Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `registry-publish` boolean input to `publish-release.yml` so callers explicitly opt in to external registry publication, then update all 11 fleet callers to specify `language`, `container-tag`, and (where applicable) `registry-publish: true`.

**Architecture:** The reusable workflow gains one new optional boolean input (`registry-publish`, default `false`). Steps that are only meaningful for external registry publication — Maven credential config, ecosystem command derivation, build, attestation, SBOM, and registry publish — are gated behind this flag. Steps that every repo needs (checkout, standard-tooling install, version extract, tag check, tag-and-release, version-bump-pr) remain ungated. Each fleet caller's `publish-release.yml` is updated to pass `language`, `container-tag`, and `registry-publish` as appropriate.

**Tech Stack:** GitHub Actions reusable workflows (YAML), `st-validate` for validation.

---

## Context

### Current state

`publish-release.yml` in standard-actions has two required inputs (`language`, `container-tag`) and several optional inputs for build/publish customization. The workflow runs every step for every caller — registry-publish steps are only skipped incidentally when derived commands are empty or credentials are missing.

All 11 fleet callers are pinned to `@v1.5`. Only `standard-tooling` passes `language: python`; the other 10 pass no `with:` inputs at all.

### Which repos publish to an external registry?

| Repository | Language | Registry | Publishes? |
|---|---|---|---|
| standard-tooling | python | PyPI | Yes |
| mq-rest-admin-python | python | PyPI | Yes |
| mq-rest-admin-go | go | (Go module proxy) | Yes |
| mq-rest-admin-java | java | Maven Central | Yes |
| mq-rest-admin-ruby | ruby | RubyGems | Yes |
| mq-rest-admin-rust | rust | crates.io | Yes |
| ai-research-methodology | python | PyPI | TBD (has pyproject.toml) |
| standard-tooling-plugin | claude-plugin | none | No |
| mq-rest-admin-common | none | none | No |
| mq-rest-admin-dev-environment | shell | none | No |
| mq-rest-admin-template | none | none | No |

### Container image tags (from standard-tooling-docker)

- `dev-python`: 3.12, 3.13, 3.14
- `dev-go`: 1.25, 1.26
- `dev-java`: 17, 21
- `dev-ruby`: 3.2, 3.3, 3.4
- `dev-rust`: 1.92, 1.93
- `dev-base`: latest

Non-language repos (`primary-language` of `none`, `shell`, `claude-plugin`) use `dev-base:latest`.

---

## Task 1: Add `registry-publish` input and gate steps in `publish-release.yml`

**Files:**
- Modify: `.github/workflows/publish-release.yml:4-58` (inputs section)
- Modify: `.github/workflows/publish-release.yml:86-233` (conditional steps)

### Input changes

- [ ] **Step 1: Revert `language` and `container-tag` to optional with defaults**

`language` defaults to `base`, `container-tag` defaults to `latest`. This lets non-language repos omit them without error, while language repos still specify them explicitly.

In `.github/workflows/publish-release.yml`, change the `language` and `container-tag` inputs:

```yaml
      language:
        description: Primary language (matches dev container image suffix).
        type: string
        default: "base"
      container-tag:
        description: Dev container image tag (e.g. 3.14, 1.26).
        type: string
        default: "latest"
```

- [ ] **Step 2: Add the `registry-publish` input**

Add after `container-tag`:

```yaml
      registry-publish:
        description: Publish build artifacts to an external package registry.
        type: boolean
        default: false
```

- [ ] **Step 3: Gate the Maven credential step on `registry-publish`**

Change line 87's `if` from:

```yaml
        if: inputs.language == 'java'
```

to:

```yaml
        if: inputs.registry-publish && inputs.language == 'java'
```

- [ ] **Step 4: Gate the "Derive ecosystem commands" step on `registry-publish`**

Change line 127's `if` from:

```yaml
        if: steps.tag_check.outputs.exists == 'false'
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 5: Gate the "Ensure dist directory" step on `registry-publish`**

Change line 178's `if` from:

```yaml
        if: steps.tag_check.outputs.exists == 'false'
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 6: Gate the "Prepare version-dependent inputs" step on `registry-publish`**

Change line 165's `if` from:

```yaml
        if: steps.tag_check.outputs.exists == 'false'
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 7: Gate the "Build" step on `registry-publish`**

Change the `if` from:

```yaml
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          steps.commands.outputs.build != ''
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          steps.commands.outputs.build != ''
```

- [ ] **Step 8: Gate the "Attest build provenance" step on `registry-publish`**

Change the `if` from:

```yaml
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          inputs.attestation-subject-path != ''
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          inputs.attestation-subject-path != ''
```

- [ ] **Step 9: Gate the "Generate SBOM" step on `registry-publish`**

Change the `if` from:

```yaml
        if: >-
          steps.tag_check.outputs.exists == 'false' &&
          inputs.sbom-output-file != ''
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false' &&
          inputs.sbom-output-file != ''
```

- [ ] **Step 10: Gate the "Publish to PyPI" step on `registry-publish`**

Change the `if` from:

```yaml
        if: >-
          inputs.language == 'python' &&
          steps.tag_check.outputs.exists == 'false'
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          inputs.language == 'python' &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 11: Gate the "Publish to registry" step on `registry-publish`**

Change the `if` from:

```yaml
        if: >-
          inputs.language != 'python' &&
          steps.commands.outputs.publish != '' &&
          steps.tag_check.outputs.exists == 'false'
```

to:

```yaml
        if: >-
          inputs.registry-publish &&
          inputs.language != 'python' &&
          steps.commands.outputs.publish != '' &&
          steps.tag_check.outputs.exists == 'false'
```

- [ ] **Step 12: Run validation**

```bash
st-docker-run -- st-validate
```

Expected: all checks pass.

- [ ] **Step 13: Commit**

```bash
st-commit --type fix --scope publish \
  --message "add registry-publish flag and make language/container-tag optional with defaults" \
  --body "Steps that publish to external registries (build, attest, SBOM, PyPI, registry publish, Maven creds, ecosystem command derivation) are now gated behind the new registry-publish boolean input (default false). language defaults to base and container-tag defaults to latest so non-language repos can omit them. Ref #402" \
  --agent claude
```

---

## Task 2: Update fleet caller — standard-tooling

This repo publishes to PyPI.

**Files:**
- Modify: `/Users/pmoore/dev/github/standard-tooling/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Change the `with:` block from:

```yaml
    with:
      language: python
```

to:

```yaml
    with:
      language: python
      container-tag: "3.14"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify container-tag and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 3: Update fleet caller — mq-rest-admin-python

This repo publishes to PyPI.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-python/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: python
      container-tag: "3.14"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 4: Update fleet caller — mq-rest-admin-go

This repo publishes as a Go module.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-go/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: go
      container-tag: "1.26"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 5: Update fleet caller — mq-rest-admin-java

This repo publishes to Maven Central.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-java/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: java
      container-tag: "17"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 6: Update fleet caller — mq-rest-admin-ruby

This repo publishes to RubyGems.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-ruby/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: ruby
      container-tag: "3.4"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 7: Update fleet caller — mq-rest-admin-rust

This repo publishes to crates.io.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-rust/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: rust
      container-tag: "1.93"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 8: Update fleet caller — ai-research-methodology

This repo has a `pyproject.toml` — confirm with owner whether it publishes to PyPI. Assuming yes:

**Files:**
- Modify: `/Users/pmoore/dev/github/ai-research-methodology/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

Add a `with:` block:

```yaml
    with:
      language: python
      container-tag: "3.14"
      registry-publish: true
```

- [ ] **Step 2: Commit**

```bash
st-commit --type fix --scope ci \
  --message "specify language, container-tag, and registry-publish in publish-release caller" \
  --body "Required by standard-actions #402. Ref wphillipmoore/standard-actions#402" \
  --agent claude
```

---

## Task 9: Update fleet caller — standard-tooling-plugin

No external registry. Uses `dev-base:latest`.

**Files:**
- Modify: `/Users/pmoore/dev/github/standard-tooling-plugin/.github/workflows/publish-release.yml`

- [ ] **Step 1: Update the workflow**

No `with:` block needed — `language` defaults to `base`, `container-tag` defaults to `latest`, `registry-publish` defaults to `false`. The existing file already works as-is with the new defaults.

Verify the file has no `with:` block and leave it unchanged. No commit needed.

---

## Task 10: Update fleet caller — mq-rest-admin-common

No external registry. Uses `dev-base:latest`.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-common/.github/workflows/publish-release.yml`

- [ ] **Step 1: Verify**

No `with:` block needed — defaults apply. Leave unchanged. No commit needed.

---

## Task 11: Update fleet caller — mq-rest-admin-dev-environment

No external registry. Uses `dev-base:latest`.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-dev-environment/.github/workflows/publish-release.yml`

- [ ] **Step 1: Verify**

No `with:` block needed — defaults apply. Leave unchanged. No commit needed.

---

## Task 12: Update fleet caller — mq-rest-admin-template

No external registry. Uses `dev-base:latest`.

**Files:**
- Modify: `/Users/pmoore/dev/github/mq-rest-admin-template/.github/workflows/publish-release.yml`

- [ ] **Step 1: Verify**

No `with:` block needed — defaults apply. Leave unchanged. No commit needed.

---

## Rollout Order

The changes must be deployed in this order:

1. **Task 1** — merge the `publish-release.yml` changes in `standard-actions` and cut a new tag (e.g. `v1.6` or update `v1.5`)
2. **Tasks 2-8** — update fleet callers to pin to the new tag and pass the new inputs
3. **Tasks 9-12** — verify the non-language repos still work with defaults (no code change needed, but confirm CI passes after the tag update)

If the `v1.5` tag is a floating tag (moved on each release), then the fleet callers must be updated *before* the tag moves — otherwise they'll break during the window between tag update and caller update. If `v1.5` is immutable, cut `v1.6` and update callers to reference `@v1.6`.
