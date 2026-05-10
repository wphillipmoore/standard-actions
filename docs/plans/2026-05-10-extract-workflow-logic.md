# Extract Workflow Logic Into Composite Actions

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all inline logic from reusable workflows into composite actions so every workflow file is a flat sequence of `uses:` calls with at most single-command `run:` lines for trivial glue.

**Architecture:** Three new composite actions (`validate-inputs`, `registry-publish`, `freeze-internal-refs`) and one modification to the existing `docs-deploy` action. The work is phased by workflow: `cd-release.yml` first (critical), then `cd.yml`, then `cd-docs.yml`.

**Tech Stack:** GitHub Actions composite actions (YAML), bash, `st-validate` for validation.

---

## Context

### Current state

Several workflows contain multi-line bash blocks, case statements, and inline credential provisioning. `cd-release.yml` is the worst offender (~90 lines of inline logic). `cd.yml` has ~40 lines of ref-freezing bash. `cd-docs.yml` has ~14 lines of language detection and mike command derivation.

### Spec

`docs/superpowers/specs/2026-05-09-extract-workflow-logic-design.md`

### Issues

- [#436](https://github.com/wphillipmoore/standard-actions/issues/436) — extract all inline logic from reusable workflows into composite actions

---

## Phase 1: `cd-release.yml` extractions

### Task 1: Create `actions/publish/validate-inputs` composite action

**Files:**
- Create: `actions/publish/validate-inputs/action.yml`

- [ ] **Step 1: Create the action file with inputs**

Create `actions/publish/validate-inputs/action.yml`:

```yaml
name: Validate publish inputs
description: >-
  Pre-flight validation for cd-release inputs. Fails early on invalid
  input combinations.

inputs:
  language:
    description: Primary language string.
    required: true
  container-tag:
    description: Dev container image tag.
    required: true
  registry-publish:
    description: Whether publishing is enabled.
    required: true

runs:
  using: composite
  steps:
    - name: Validate inputs
      shell: bash
      env:
        INPUT_LANGUAGE: ${{ inputs.language }}
        INPUT_CONTAINER_TAG: ${{ inputs.container-tag }}
        INPUT_REGISTRY_PUBLISH: ${{ inputs.registry-publish }}
      run: |
        supported_languages="python java ruby rust go"

        if [ "$INPUT_LANGUAGE" != "base" ] && \
           [ "$INPUT_CONTAINER_TAG" = "latest" ]; then
          echo "::error::language '${INPUT_LANGUAGE}' requires an explicit container-tag (language-specific images do not publish a :latest tag)"
          exit 1
        fi

        if [ "$INPUT_REGISTRY_PUBLISH" = "true" ] && \
           [ "$INPUT_LANGUAGE" = "base" ]; then
          echo "::error::registry-publish requires a language to derive ecosystem build/publish commands"
          exit 1
        fi

        if [ "$INPUT_REGISTRY_PUBLISH" = "true" ]; then
          found=0
          for lang in $supported_languages; do
            if [ "$INPUT_LANGUAGE" = "$lang" ]; then
              found=1
              break
            fi
          done
          if [ "$found" -eq 0 ]; then
            echo "::error::unsupported language '${INPUT_LANGUAGE}' for registry publishing (supported: ${supported_languages})"
            exit 1
          fi
        fi
```

**Verification:** `st-docker-run -- st-validate` passes (actionlint will parse the new action).

---

### Task 2: Create `actions/publish/registry-publish` composite action

**Files:**
- Create: `actions/publish/registry-publish/action.yml`

This is the largest single task. The action encapsulates ecosystem command derivation, Maven credential provisioning, build, attestation, SBOM generation, and publish execution.

- [ ] **Step 1: Create the action file with inputs and outputs**

Create `actions/publish/registry-publish/action.yml` with the full input/output declarations:

```yaml
name: Registry publish
description: >-
  Full build-and-publish pipeline for any supported language ecosystem.
  Handles command derivation, credential provisioning, build,
  attestation, SBOM generation, and publish execution.

inputs:
  language:
    description: Primary language (python, rust, ruby, java, go).
    required: true
  version:
    description: Semver version string (e.g. 1.2.3).
    required: true
  build-command:
    description: Override ecosystem-derived build command.
    required: false
    default: ""
  publish-command:
    description: Override ecosystem-derived publish command.
    required: false
    default: ""
  attestation-subject-path:
    description: Glob for build provenance attestation. Leave empty to skip.
    required: false
    default: ""
  sbom-output-file:
    description: SBOM output path ($VERSION placeholder). Leave empty to skip.
    required: false
    default: ""
  cargo-registry-token:
    description: "Rust: crates.io token."
    required: false
    default: ""
  rubygems-api-key:
    description: "Ruby: RubyGems API key."
    required: false
    default: ""
  central-username:
    description: "Java: Maven Central username."
    required: false
    default: ""
  central-token:
    description: "Java: Maven Central token."
    required: false
    default: ""
  gpg-private-key:
    description: "Java: GPG signing key."
    required: false
    default: ""
  gpg-passphrase:
    description: "Java: GPG passphrase."
    required: false
    default: ""

outputs:
  build-command:
    description: Resolved build command (derived or overridden).
    value: ${{ steps.commands.outputs.build }}
  publish-command:
    description: Resolved publish command (derived or overridden).
    value: ${{ steps.commands.outputs.publish }}
  sbom-output-file:
    description: Resolved SBOM path (empty if skipped).
    value: ${{ steps.resolve.outputs.sbom-output-file }}

runs:
  using: composite
  steps:
```

- [ ] **Step 2: Add the ecosystem command derivation step**

Append to the `steps:` list. Uses `env:` for all inputs per the security constraint (design decision #6). Includes a default guard for unrecognized languages.

```yaml
    - name: Derive ecosystem commands
      id: commands
      shell: bash
      env:
        INPUT_LANGUAGE: ${{ inputs.language }}
        INPUT_BUILD_COMMAND: ${{ inputs.build-command }}
        INPUT_PUBLISH_COMMAND: ${{ inputs.publish-command }}
      run: |
        build="$INPUT_BUILD_COMMAND"
        if [ -z "$build" ]; then
          case "$INPUT_LANGUAGE" in
            python) build="uv build" ;;
            rust)   build="cargo build --release" ;;
            ruby)   build="gem build *.gemspec" ;;
            java)   build="./mvnw -B package -DskipTests" ;;
            go)     build="go build ./..." ;;
            *)
              echo "::error::unrecognized language '${INPUT_LANGUAGE}' — cannot derive build command"
              exit 1
              ;;
          esac
        fi
        echo "build=$build" >> "$GITHUB_OUTPUT"

        publish="$INPUT_PUBLISH_COMMAND"
        if [ -z "$publish" ]; then
          case "$INPUT_LANGUAGE" in
            python) publish="uv publish dist/*" ;;
            rust)   publish="cargo publish" ;;
            ruby)   publish="gem push *.gem" ;;
            java)   publish="./mvnw -B deploy -DskipTests" ;;
            go)     publish="" ;;
            *)
              echo "::error::unrecognized language '${INPUT_LANGUAGE}' — cannot derive publish command"
              exit 1
              ;;
          esac
        fi
        echo "publish=$publish" >> "$GITHUB_OUTPUT"

        case "$INPUT_LANGUAGE" in
          rust) echo "credential-secret=CARGO_REGISTRY_TOKEN" >> "$GITHUB_OUTPUT" ;;
          ruby) echo "credential-secret=RUBYGEMS_API_KEY" >> "$GITHUB_OUTPUT" ;;
          java) echo "credential-secret=CENTRAL_TOKEN" >> "$GITHUB_OUTPUT" ;;
          *)    echo "credential-secret=" >> "$GITHUB_OUTPUT" ;;
        esac
```

- [ ] **Step 3: Add Maven credential provisioning step**

```yaml
    - name: Configure Maven credentials
      if: inputs.language == 'java'
      shell: bash
      env:
        GPG_PRIVATE_KEY: ${{ inputs.gpg-private-key }}
      run: |
        mkdir -p ~/.m2
        cat > ~/.m2/settings.xml << 'XML'
        <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
          <servers>
            <server>
              <id>central</id>
              <username>${env.MAVEN_USERNAME}</username>
              <password>${env.MAVEN_PASSWORD}</password>
            </server>
          </servers>
        </settings>
        XML
        if [ -n "$GPG_PRIVATE_KEY" ]; then
          echo "$GPG_PRIVATE_KEY" | gpg --batch --import
        fi
```

- [ ] **Step 4: Add version placeholder resolution step**

```yaml
    - name: Resolve version placeholders
      id: resolve
      shell: bash
      env:
        VERSION: ${{ inputs.version }}
        SBOM_OUTPUT_FILE: ${{ inputs.sbom-output-file }}
      run: |
        echo "sbom-output-file=${SBOM_OUTPUT_FILE//\$VERSION/$VERSION}" \
          >> "$GITHUB_OUTPUT"
```

- [ ] **Step 5: Add build steps (mkdir, build, attestation, SBOM)**

```yaml
    - name: Ensure dist directory
      shell: bash
      run: mkdir -p dist

    - name: Build
      if: steps.commands.outputs.build != ''
      shell: bash
      env:
        VERSION: ${{ inputs.version }}
        BUILD_CMD: ${{ steps.commands.outputs.build }}
      run: eval "$BUILD_CMD"

    - name: Attest build provenance
      if: inputs.attestation-subject-path != ''
      uses: actions/attest-build-provenance@v4
      with:
        subject-path: ${{ inputs.attestation-subject-path }}

    - name: Generate SBOM
      if: inputs.sbom-output-file != ''
      uses: wphillipmoore/standard-actions/actions/security/trivy@develop
      with:
        scan-type: sbom
        output-file: ${{ steps.resolve.outputs.sbom-output-file }}
```

- [ ] **Step 6: Add the publish step**

Single path for all languages. Credential guard checks the relevant secret is non-empty before executing. Skips entirely if the resolved publish command is empty.

```yaml
    - name: Publish
      if: steps.commands.outputs.publish != ''
      shell: bash
      env:
        VERSION: ${{ inputs.version }}
        PUBLISH_CMD: ${{ steps.commands.outputs.publish }}
        CREDENTIAL_SECRET: ${{ steps.commands.outputs.credential-secret }}
        CARGO_REGISTRY_TOKEN: ${{ inputs.cargo-registry-token }}
        GEM_HOST_API_KEY: ${{ inputs.rubygems-api-key }}
        MAVEN_USERNAME: ${{ inputs.central-username }}
        MAVEN_PASSWORD: ${{ inputs.central-token }}
        MAVEN_GPG_PASSPHRASE: ${{ inputs.gpg-passphrase }}
      run: |
        if [ -n "$CREDENTIAL_SECRET" ]; then
          val=$(printenv "$CREDENTIAL_SECRET" 2>/dev/null || true)
          if [ -z "$val" ]; then
            echo "::notice::${CREDENTIAL_SECRET} not configured — skipping publish"
            exit 0
          fi
        fi
        eval "$PUBLISH_CMD"
```

**Verification:** `st-docker-run -- st-validate` passes.

---

### Task 3: Rewrite `cd-release.yml` to use the new actions

**Files:**
- Modify: `.github/workflows/cd-release.yml`

- [ ] **Step 1: Replace the inline validate-inputs block**

In `.github/workflows/cd-release.yml`, replace the current "Validate inputs" step (lines 87–102):

```yaml
      - name: Validate inputs
        env:
          INPUT_LANGUAGE: ${{ inputs.language }}
          INPUT_CONTAINER_TAG: ${{ inputs.container-tag }}
          INPUT_REGISTRY_PUBLISH: ${{ inputs.registry-publish }}
        run: |
          if [ "$INPUT_LANGUAGE" != "base" ] && \
             [ "$INPUT_CONTAINER_TAG" = "latest" ]; then
            echo "::error::language '${INPUT_LANGUAGE}' requires an explicit container-tag (language-specific images do not publish a :latest tag)"
            exit 1
          fi
          if [ "$INPUT_REGISTRY_PUBLISH" = "true" ] && \
             [ "$INPUT_LANGUAGE" = "base" ]; then
            echo "::error::registry-publish requires a language to derive ecosystem build/publish commands"
            exit 1
          fi
```

with:

```yaml
      - name: Validate inputs
        uses: ./actions/publish/validate-inputs
        with:
          language: ${{ inputs.language }}
          container-tag: ${{ inputs.container-tag }}
          registry-publish: ${{ inputs.registry-publish }}
```

- [ ] **Step 2: Remove all inline publish logic and replace with registry-publish**

Remove these steps from `cd-release.yml`:
- "Configure Maven credentials" (lines 107–127)
- "Derive ecosystem commands" (lines 145–181)
- "Prepare version-dependent inputs" (lines 183–196) — keep only the `release-artifacts` resolution
- "Ensure dist directory" (lines 198–202)
- "Build" (lines 204–211)
- "Attest build provenance" (lines 213–219)
- "Generate SBOM" (lines 221–230)
- "Publish to PyPI" (lines 232–237)
- "Publish to registry" (lines 239–261)

Replace with a single `release-artifacts` resolution step and the `registry-publish` action call:

```yaml
      - name: Resolve release artifacts
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
        id: resolved
        env:
          VERSION: ${{ steps.version.outputs.version }}
          RELEASE_ARTIFACTS: ${{ inputs.release-artifacts }}
        run: |
          echo "release-artifacts=${RELEASE_ARTIFACTS//\$VERSION/$VERSION}" \
            >> "$GITHUB_OUTPUT"

      - name: Publish
        if: >-
          inputs.registry-publish &&
          steps.tag_check.outputs.exists == 'false'
        uses: ./actions/publish/registry-publish
        with:
          language: ${{ inputs.language }}
          version: ${{ steps.version.outputs.version }}
          build-command: ${{ inputs.build-command }}
          publish-command: ${{ inputs.registry-publish-command }}
          attestation-subject-path: ${{ inputs.attestation-subject-path }}
          sbom-output-file: ${{ inputs.sbom-output-file }}
          cargo-registry-token: ${{ secrets.CARGO_REGISTRY_TOKEN }}
          rubygems-api-key: ${{ secrets.RUBYGEMS_API_KEY }}
          central-username: ${{ secrets.CENTRAL_USERNAME }}
          central-token: ${{ secrets.CENTRAL_TOKEN }}
          gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
          gpg-passphrase: ${{ secrets.GPG_PASSPHRASE }}
```

- [ ] **Step 3: Update the `tag-and-release` step's release-artifacts reference**

The `tag-and-release` step currently references `${{ steps.resolved.outputs.release-artifacts }}`. This still works since the `resolved` step ID is preserved. Verify this reference is correct — no change needed if the step ID matches.

**Verification:** `st-docker-run -- st-validate` passes. The resulting `cd-release.yml` should contain no multi-line bash blocks beyond version extraction and tag check.

---

## Phase 2: `cd.yml` extraction

### Task 4: Create `actions/publish/freeze-internal-refs` composite action

**Files:**
- Create: `actions/publish/freeze-internal-refs/action.yml`

- [ ] **Step 1: Create the action file**

Create `actions/publish/freeze-internal-refs/action.yml`:

```yaml
name: Freeze internal refs
description: >-
  Rewrites relative action refs (./actions/X) and @develop refs to
  absolute tagged refs across all workflow and action YAML files, then
  validates no unfrozen refs remain. Commits the result.

inputs:
  tag:
    description: Release tag to freeze to (e.g. v1.5.20).
    required: true
  owner-repo:
    description: Owner/repo string for absolute refs.
    required: false
    default: ${{ github.repository }}

runs:
  using: composite
  steps:
    - name: Configure git identity
      shell: bash
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

    - name: Freeze refs
      shell: bash
      env:
        RELEASE_TAG: ${{ inputs.tag }}
        OWNER_REPO: ${{ inputs.owner-repo }}
      run: |
        set -euo pipefail
        mapfile -t files < <(find .github/workflows actions \
          -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
        for f in "${files[@]}"; do
          sed -i.bak -E "/uses:/s|\./actions/([^[:space:]]+)|${OWNER_REPO}/actions/\1@${RELEASE_TAG}|g" "$f"
          sed -i.bak -E "/uses:/s|(${OWNER_REPO}/[^@[:space:]]+)@develop|\1@${RELEASE_TAG}|g" "$f"
          rm -f "$f.bak"
        done

    - name: Validate no unfrozen refs
      shell: bash
      env:
        OWNER_REPO: ${{ inputs.owner-repo }}
      run: |
        set -euo pipefail
        mapfile -t files < <(find .github/workflows actions \
          -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
        failed=0
        for f in "${files[@]}"; do
          if grep -nE 'uses:\s+\./actions/' "$f"; then
            echo "::error file=${f}::Unfrozen relative action ref (./actions/)"
            failed=1
          fi
          if grep -nE "${OWNER_REPO}/[^@[:space:]]+@develop" "$f"; then
            echo "::error file=${f}::Unfrozen @develop action ref"
            failed=1
          fi
        done
        if [ "${failed}" -ne 0 ]; then
          echo "::error::Internal refs were not fully frozen — aborting"
          exit 1
        fi

    - name: Commit frozen refs
      shell: bash
      env:
        RELEASE_TAG: ${{ inputs.tag }}
      run: |
        if ! git diff --quiet; then
          git add .github/workflows actions
          git commit -m "chore(release): freeze internal refs to ${RELEASE_TAG}"
        fi
```

**Verification:** `st-docker-run -- st-validate` passes.

---

### Task 5: Rewrite `cd.yml` to use `freeze-internal-refs`

**Files:**
- Modify: `.github/workflows/cd.yml`

- [ ] **Step 1: Replace inline freeze and validate steps**

In `.github/workflows/cd.yml`, replace the "Freeze internal refs to release tag" step (lines 68–86) and "Validate no unfrozen internal refs" step (lines 88–108) with:

```yaml
      - name: Freeze internal refs to release tag
        if: steps.tag_check.outputs.exists == 'false'
        uses: ./actions/publish/freeze-internal-refs
        with:
          tag: ${{ steps.version.outputs.tag }}
```

Remove the comment block above the old freeze step (lines 62–67) as it describes the inline implementation — the action's own description replaces it.

**Verification:** `st-docker-run -- st-validate` passes. The release job in `cd.yml` should contain no multi-line bash beyond version extraction and tag check.

---

## Phase 3: `cd-docs.yml` / `docs-deploy` modification

### Task 6: Modify `actions/docs-deploy` to auto-detect mike command

**Files:**
- Modify: `actions/docs-deploy/action.yml`

- [ ] **Step 1: Change `mike-command` input default**

In `actions/docs-deploy/action.yml`, change the `mike-command` input default from `mike` to `""`:

Replace:

```yaml
  mike-command:
    description: >-
      Command to run mike. Set to "uv run mike" for Python repos that
      manage their own dependencies via their project's virtual
      environment.
    required: false
    default: mike
```

with:

```yaml
  mike-command:
    description: >-
      Command to run mike. Auto-detected from standard-tooling.toml when
      omitted: "uv run mike" for Python repos, "mike" otherwise. Set
      explicitly to override.
    required: false
    default: ""
```

- [ ] **Step 2: Add mike command resolution step**

Insert a new step after the "Configure git identity" step and before the "Determine version" step:

```yaml
    - name: Resolve mike command
      id: mike-cmd
      shell: bash
      working-directory: ${{ github.workspace }}
      env:
        INPUT_MIKE_COMMAND: ${{ inputs.mike-command }}
      run: |
        if [ -n "$INPUT_MIKE_COMMAND" ]; then
          echo "cmd=$INPUT_MIKE_COMMAND" >> "$GITHUB_OUTPUT"
        else
          lang=$(/usr/local/bin/python3 -c "
          import tomllib, pathlib
          cfg = tomllib.loads(pathlib.Path('standard-tooling.toml').read_text())
          print(cfg['project']['primary-language'])
          ")
          if [ "$lang" = "python" ]; then
            echo "cmd=uv run mike" >> "$GITHUB_OUTPUT"
          else
            echo "cmd=mike" >> "$GITHUB_OUTPUT"
          fi
        fi
```

- [ ] **Step 3: Update all mike command references**

Replace all occurrences of `${{ inputs.mike-command }}` in subsequent steps with `${{ steps.mike-cmd.outputs.cmd }}`. This affects the "Deploy docs" step (the last step in the action).

**Verification:** `st-docker-run -- st-validate` passes.

---

### Task 7: Simplify `cd-docs.yml` workflow

**Files:**
- Modify: `.github/workflows/cd-docs.yml`

- [ ] **Step 1: Remove the "Detect ecosystem" step**

Remove the entire "Detect ecosystem" step (lines 36–46):

```yaml
      - name: Detect ecosystem
        id: ecosystem
        shell: bash
        run: |
          # Absolute path: a project venv can shadow python3 (see #418).
          lang=$(/usr/local/bin/python3 -c "
          import tomllib, pathlib
          cfg = tomllib.loads(pathlib.Path('standard-tooling.toml').read_text())
          print(cfg['project']['primary-language'])
          ")
          echo "language=$lang" >> "$GITHUB_OUTPUT"
```

- [ ] **Step 2: Remove the "Determine mike command" step**

Remove the entire "Determine mike command" step (lines 55–63):

```yaml
      - name: Determine mike command
        id: mike
        shell: bash
        run: |
          if [ "${{ steps.ecosystem.outputs.language }}" = "python" ]; then
            echo "cmd=uv run mike" >> "$GITHUB_OUTPUT"
          else
            echo "cmd=mike" >> "$GITHUB_OUTPUT"
          fi
```

- [ ] **Step 3: Remove `mike-command` from the Deploy docs step**

In the "Deploy docs" step, remove the `mike-command` line:

Replace:

```yaml
      - name: Deploy docs
        uses: ./actions/docs-deploy
        with:
          version-command: st-version show --major-minor
          mkdocs-config: ${{ inputs.mkdocs-config || 'docs/site/mkdocs.yml' }}
          mike-command: ${{ steps.mike.outputs.cmd }}
```

with:

```yaml
      - name: Deploy docs
        uses: ./actions/docs-deploy
        with:
          version-command: st-version show --major-minor
          mkdocs-config: ${{ inputs.mkdocs-config || 'docs/site/mkdocs.yml' }}
```

**Verification:** `st-docker-run -- st-validate` passes. The workflow should contain no multi-line bash blocks.

---

## Final validation

### Task 8: Full validation and acceptance criteria check

- [ ] **Step 1: Run full validation**

```bash
st-docker-run -- st-validate
```

- [ ] **Step 2: Verify acceptance criteria from issue #436**

Check each criterion:
- `cd-release.yml` contains no multi-line bash blocks (only version extraction and tag check glue)
- `cd.yml` ref-freezing and validation logic extracted to composite action
- `cd-docs.yml` language detection and mike command derivation extracted
- No workflow file contains a bash `case` statement
- No workflow file contains inline credential provisioning
- CI passes
