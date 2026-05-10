# Extract inline workflow logic into composite actions

**Issue:** [#436](https://github.com/wphillipmoore/standard-actions/issues/436)
**Date:** 2026-05-09
**Status:** Approved

## Goal

Reusable workflow files should be two layers of shims: a `workflow_call`
trigger wiring inputs to composite action calls. All substantive logic
(case statements, multi-line shell, credential provisioning,
language-specific conditionals) moves into composite actions under
`actions/`.

## Scope

### In scope

| Deliverable | Type | Target workflow |
|-------------|------|-----------------|
| `actions/publish/validate-inputs` | New action | `cd-release.yml` |
| `actions/publish/registry-publish` | New action | `cd-release.yml` |
| `actions/publish/freeze-internal-refs` | New action | `cd.yml` |
| `actions/docs-deploy` modification | Existing action | `cd-docs.yml` |

### Out of scope

The single-line `uv sync` conditionals in `ci-quality.yml`, `ci-test.yml`,
and `ci-audit.yml` are left as-is. They are already at shim level (one-line
`if` + `run`).

## Design decisions

1. **Merged publish pipeline.** Ecosystem command derivation, Maven
   credential provisioning, and conditional publish logic are combined into
   a single `registry-publish` action rather than split across three
   actions. The command derivation and credential setup are implementation
   details of publishing; no caller needs intermediate outputs
   independently.

2. **Standalone input validation.** `validate-inputs` remains a separate
   action because it gates the entire job, not just the publish step. It
   runs before any real work begins.

3. **Atomic ref freezing.** The freeze-and-validate cycle is a single
   action. Validation is a postcondition of freezing; splitting them would
   let a caller freeze without validating, which is always a bug.

4. **Auto-detect in docs-deploy.** Language detection and mike command
   derivation fold into the existing `docs-deploy` action. The action
   auto-detects when no `mike-command` is provided, avoiding a
   single-purpose detection action that only one workflow uses.

5. **Explicit secret inputs.** `registry-publish` takes each credential as
   an optional input. Transparent and auditable, matching the pattern used
   by `version-bump-pr`.

6. **`env:` over `${{ }}` in shell.** All action inputs passed to `run:`
   steps use `env:` variables, never direct `${{ }}` interpolation. This
   prevents expression injection from caller-provided values.

---

## Action specifications

### `actions/publish/validate-inputs`

Pre-flight validation for `cd-release.yml` inputs.

**Inputs:**

| Input | Required | Description |
|-------|----------|-------------|
| `language` | yes | Primary language string |
| `container-tag` | yes | Dev container image tag |
| `registry-publish` | yes | Whether publishing is enabled |

**Outputs:** None.

**Behavior:**

1. If `language` is not `base` and `container-tag` is `latest` — fail with
   error: language-specific images do not publish a `:latest` tag.
2. If `registry-publish` is `true` and `language` is `base` — fail with
   error: publishing requires a language to derive ecosystem commands.
3. If `registry-publish` is `true` and `language` is not in the supported
   set (`python`, `java`, `ruby`, `rust`, `go`) — fail with error: unsupported
   language for registry publishing. The supported set is maintained as a
   single list for easy extension as new ecosystems are added.

Passes silently on success.

---

### `actions/publish/registry-publish`

Full build-and-publish pipeline for any supported language ecosystem.
Handles command derivation, credential provisioning, build, attestation,
SBOM generation, credential guarding, and publish execution.

**Inputs:**

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `language` | yes | — | Primary language (`python`, `rust`, `ruby`, `java`, `go`) |
| `version` | yes | — | Semver version string |
| `build-command` | no | `""` | Override ecosystem-derived build command |
| `publish-command` | no | `""` | Override ecosystem-derived publish command |
| `attestation-subject-path` | no | `""` | Glob for build provenance attestation |
| `sbom-output-file` | no | `""` | SBOM output path (`$VERSION` placeholder) |
| `cargo-registry-token` | no | `""` | Rust: crates.io token |
| `rubygems-api-key` | no | `""` | Ruby: RubyGems API key |
| `central-username` | no | `""` | Java: Maven Central username |
| `central-token` | no | `""` | Java: Maven Central token |
| `gpg-private-key` | no | `""` | Java: GPG signing key |
| `gpg-passphrase` | no | `""` | Java: GPG passphrase |

> **Name mapping note:** The workflow-level input `registry-publish-command`
> maps to this action's `publish-command` input. The `registry-` prefix is
> redundant within the action's own namespace. A broader namespace
> rationalization is tracked in #440.

**Outputs:**

| Output | Description |
|--------|-------------|
| `build-command` | Resolved build command (derived or overridden) |
| `publish-command` | Resolved publish command (derived or overridden) |
| `sbom-output-file` | Resolved SBOM path (empty if skipped) |

**Internal steps (in order):**

1. **Derive ecosystem commands** — case statement mapping language to
   default build command, publish command, and credential secret name.
   Caller overrides take precedence.

   | Language | Build | Publish | Credential |
   |----------|-------|---------|------------|
   | `python` | `uv build` | `uv publish dist/*` | (trusted publishing) |
   | `rust` | `cargo build --release` | `cargo publish` | `CARGO_REGISTRY_TOKEN` |
   | `ruby` | `gem build *.gemspec` | `gem push *.gem` | `GEM_HOST_API_KEY` |
   | `java` | `./mvnw -B package -DskipTests` | `./mvnw -B deploy -DskipTests` | `CENTRAL_TOKEN` |
   | `go` | `go build ./...` | _(no registry publish)_ | — |

   The case statement includes a default guard that fails with an error for
   unrecognized languages (defense in depth — `validate-inputs` catches this
   first).

2. **Maven credential provisioning** — if `language == java`: write
   `~/.m2/settings.xml` referencing `MAVEN_USERNAME`/`MAVEN_PASSWORD` env
   vars, import GPG private key. Skipped for other languages.

3. **Resolve version placeholders** — replace `$VERSION` in
   `sbom-output-file` with the actual version string.

4. **Ensure dist directory** — `mkdir -p dist`.

5. **Build** — run the resolved build command. Skip if empty.

6. **Attest build provenance** — call `actions/attest-build-provenance@v4`
   if `attestation-subject-path` is set.

7. **Generate SBOM** — call
   `wphillipmoore/standard-actions/actions/security/trivy@develop` with
   `scan-type: sbom` if `sbom-output-file` is set.

8. **Publish** — single path for all languages. Execute the resolved
   publish command (derived or overridden). If the language has a credential
   secret defined, check that it is non-empty before executing; if missing,
   emit `::notice::` and skip. Languages with no credential requirement
   (Python via trusted publishing, Go with no registry) skip the guard.
   If the resolved publish command is empty, skip the step entirely.

**Security constraint:** All inputs passed to shell steps must use `env:`
variables, not `${{ }}` expression interpolation in `run:` blocks. This
prevents expression injection from caller-provided override inputs
(`build-command`, `publish-command`). Example: use
`env: { BUILD_CMD: "${{ inputs.build-command }}" }` then `$BUILD_CMD` in
the script, not `${{ inputs.build-command }}` directly in the shell.

**Permissions note:** Steps 6 (attestation) and 7 (SBOM/Trivy) require
`id-token: write` and `attestations: write` on the calling workflow's job.
The `cd-release.yml` job already declares these permissions — no change
needed. Composite actions inherit the caller's permissions.

---

### `actions/publish/freeze-internal-refs`

Rewrites relative and `@develop` action refs to absolute tagged refs across
all workflow and action YAML files, then validates completeness.

**Inputs:**

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `tag` | yes | — | Release tag (e.g. `v1.5.20`) |
| `owner-repo` | no | `${{ github.repository }}` | Owner/repo for absolute refs |

**Outputs:** None.

**Internal steps (in order):**

1. **Configure git identity** — `github-actions[bot]`.

2. **Freeze refs** — find all `.yml`/`.yaml` files under
   `.github/workflows` and `actions/`. Two sed passes, restricted to
   lines matching `uses:` (avoids rewriting comments or strings):
   - `./actions/X` → `{owner-repo}/actions/X@{tag}`
   - `{owner-repo}/...@develop` → `{owner-repo}/...@{tag}`

3. **Validate** — scan the same files for any remaining `./actions/`
   relative refs or `@develop` refs. Emit `::error` annotations with file
   and line info on failure.

4. **Commit** — if diff is non-empty, stage and commit with message
   `chore(release): freeze internal refs to {tag}`. No-op if no changes.

---

### `actions/docs-deploy` modification

**Change:** Auto-detect mike command when `mike-command` input is not
explicitly provided.

**Input change:**

| Input | Before | After |
|-------|--------|-------|
| `mike-command` | default: `mike` | default: `""` (auto-detect) |

**New step** (inserted after git config, before version detection):

Resolve mike command:
- If `mike-command` input is non-empty — use it as-is.
- Otherwise read `standard-tooling.toml` via
  `/usr/local/bin/python3` + `tomllib`:
  - `primary-language == python` → `uv run mike`
  - Otherwise → `mike`

All subsequent steps reference the resolved command instead of the raw
input.

**Backward compatibility:** Non-Python repos that omit `mike-command` get
auto-detection which falls back to `mike` — no behavior change. Python
repos that already pass `uv run mike` explicitly continue to work.

---

## Resulting workflow shapes

### `cd-release.yml`

After extraction, the workflow steps are:

1. `actions/checkout@v6`
2. `./actions/publish/validate-inputs` — pre-flight checks
3. `./actions/setup/standard-tooling`
4. Version extraction (trivial `$GITHUB_OUTPUT` glue)
5. Tag existence check (trivial `$GITHUB_OUTPUT` glue)
6. Release-artifacts `$VERSION` resolution (one-liner)
7. `./actions/publish/registry-publish` — full publish pipeline
8. `./actions/publish/tag-and-release`
9. `actions/create-github-app-token@v3`
10. `./actions/publish/version-bump-pr`

No case statements, no inline credential provisioning, no multi-line bash.

### `cd.yml`

The release job replaces ~40 lines of inline bash with:

1. `actions/create-github-app-token@v3`
2. `actions/checkout@v6`
3. `./actions/setup/standard-tooling`
4. Version extraction + tag check (trivial glue)
5. `./actions/publish/freeze-internal-refs`
6. `./actions/publish/tag-and-release`
7. `./actions/publish/version-bump-pr`

### `cd-docs.yml`

Two steps removed (detect ecosystem, determine mike command):

1. `actions/checkout@v6`
2. `./actions/setup/standard-tooling`
3. Pre-deploy command (optional, one-liner)
4. `./actions/docs-deploy` — auto-detects mike command internally

### CI workflows

`ci-quality.yml`, `ci-test.yml`, `ci-audit.yml` are unchanged.

## Implementation phases

1. **Phase 1 — `cd-release.yml` extractions (critical):**
   `validate-inputs` and `registry-publish` actions, workflow rewrite.

2. **Phase 2 — `cd.yml` extraction:**
   `freeze-internal-refs` action, workflow rewrite.

3. **Phase 3 — `cd-docs.yml` / `docs-deploy` modification:**
   Auto-detect mike command, workflow simplification.

Each phase is independently shippable and testable.

## Testing

This repository's CI uses local paths (`./actions/...`), so changes to
actions are validated by the same PR that modifies them. Each phase should
pass the existing CI suite before merging.

The `cd-release.yml` and `cd.yml` changes affect the release pipeline and
cannot be fully end-to-end tested in CI — they require a real release
trigger. Validation strategy: ensure CI passes (actionlint, shellcheck,
yamllint), then trigger a test release after merging.
