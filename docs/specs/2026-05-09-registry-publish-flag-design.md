# Registry Publish Flag Design

**Issues:**
- [#411 — feat: make PyPI publishing opt-in for Python repos in publish-release workflow](https://github.com/wphillipmoore/standard-actions/issues/411)
- [#412 — feat: add registry-publish flag to publish-release.yml and update fleet callers](https://github.com/wphillipmoore/standard-actions/issues/412)

**Date:** 2026-05-09

**Status:** Ready for implementation

## Problem

The `publish-release.yml` reusable workflow unconditionally runs registry
publication steps for all callers. For Python repos, `uv publish dist/*`
runs whenever `inputs.language == 'python'`, regardless of whether the repo
has a PyPI trusted publisher configured. For non-Python repos, registry
publish is skipped only incidentally when derived commands are empty or
credentials are missing.

This causes two problems:

1. **PyPI publish failures** for Python repos that don't publish to PyPI
   (e.g., standard-tooling, ai-research-methodology). The step fails with
   a 422 "invalid-publisher" error, blocking releases.
2. **Unnecessary inputs** for non-language repos. `language` and
   `container-tag` are required even for repos that don't publish to any
   registry and don't need a language-specific container.

## Design

### Approach

Add a single `registry-publish` boolean input (default `false`) to the
reusable workflow. Callers that publish to an external package registry
opt in explicitly. Make `language` and `container-tag` optional with
sensible defaults so non-language repos can omit them entirely.

### Workflow input changes

Three changes to `publish-release.yml` inputs:

1. **`language`** — remove `required: true`, add `default: "base"`.
   Non-language repos get the `dev-base` container image automatically.
2. **`container-tag`** — remove `required: true`, add `default: "latest"`.
   Pairs with the `base` default above.
3. **`registry-publish`** (new) — `type: boolean`, `default: false`.
   Opt-in flag that gates all registry-specific steps.

The container image resolution is unchanged:
`ghcr.io/wphillipmoore/dev-${{ inputs.language }}:${{ inputs.container-tag }}`
resolves to `dev-base:latest` by default. Note: the `latest` default is only
valid when paired with `language: base` (the default). Language-specific
container images (e.g., `dev-python`) do not publish a `:latest` tag, so
callers that specify a language must also specify a `container-tag`.

### Step gating

`inputs.registry-publish` is prepended (with `&&`) to each gated step's
existing `if` condition. No step restructuring or new jobs — just an
additional boolean guard.

**Gated behind `registry-publish`:**

- Configure Maven credentials
- Derive ecosystem commands
- Prepare version-dependent inputs
- Ensure dist directory
- Build
- Attest build provenance
- Generate SBOM
- Publish to PyPI
- Publish to registry

**New validation step (runs before any other logic):**

- Validate input pairing: fail fast with a clear error if:
  - `language != 'base'` and `container-tag == 'latest'` (language-specific
    container images do not publish a `:latest` tag), or
  - `registry-publish == true` and `language == 'base'` (registry publishing
    requires a language to derive ecosystem build/publish commands).

**Ungated (run for every release):**

- Checkout code
- Install standard-tooling
- Extract version
- Check if tag already exists
- Tag and release
- Generate app token for bump PR
- Version bump PR

### Fleet caller updates

11 repos, split by whether they publish to an external registry:

**Repos that publish (`registry-publish: true`):**

| Repository | `language` | `container-tag` | `registry-publish` |
|---|---|---|---|
| mq-rest-admin-python | `python` | `3.14` | `true` |
| mq-rest-admin-go | `go` | `1.26` | `true` |
| mq-rest-admin-java | `java` | `17` | `true` |
| mq-rest-admin-ruby | `ruby` | `3.4` | `true` |
| mq-rest-admin-rust | `rust` | `1.93` | `true` |

**Repos that need a language container but don't publish:**

| Repository | `language` | `container-tag` | `registry-publish` |
|---|---|---|---|
| standard-tooling | `python` | `3.14` | _(default false)_ |
| ai-research-methodology | `python` | `3.14` | _(default false)_ |

**Repos that use all defaults (no `with:` block needed):**

| Repository |
|---|
| standard-tooling-plugin |
| mq-rest-admin-common |
| mq-rest-admin-dev-environment |
| mq-rest-admin-template |

### Rollout

The `v1.5` tag is floating. The change alters the semantic contract of
`v1.5`: `language` and `container-tag` shift from required to optional with
defaults, and registry-specific steps now require explicit opt-in. Existing
callers that pass `language` and `container-tag` are unaffected. Callers
that omit them will get `dev-base:latest` instead of a validation error.
Since there are no external consumers, the plan is:

1. Merge the `publish-release.yml` changes in standard-actions (moves `v1.5`).
2. Immediately roll out fleet caller updates to pass `language`,
   `container-tag`, and `registry-publish` as appropriate.

## What this does NOT change

- No new workflow jobs or step restructuring.
- No changes to `standard-tooling.toml` — the `registry-publish` flag is a
  workflow-level concern, not repo metadata.
- No changes to the tag-and-release or version-bump-pr composite actions.
- No changes to the existing credential-guard pattern on the non-Python
  publish step (it remains as a secondary safeguard).
