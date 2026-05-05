# CI reusable workflow reset — unified validation architecture

**Issue:** [#337](https://github.com/wphillipmoore/standard-actions/issues/337)
**Date:** 2026-05-05
**Status:** Design

## Context

Three of five CI reusable workflows in standard-actions v1.5 are stubs
that echo a placeholder and exit 0. A fourth (ci-quality.yml) has real
tool invocations for its common job (enforcement of all five common
checks was completed in PR #336), but its language-specific lint and
typecheck jobs are still stubs. Only ci-security.yml is fully
implemented.

Consumer repos that upgraded to v1.5 worked around the stubs by writing
fully bespoke CI jobs — duplicating the logic that should live in the
reusable workflows. This is the exact opposite of the intended
architecture.

The root cause is that the validation command registry
(`validate_commands.py` in standard-tooling) defines canonical commands
per language but nothing executes from it. The execution path goes
through bespoke `scripts/dev/{lint,typecheck,test,audit}.sh` scripts in
each consumer repo. Those scripts duplicate what the registry already
knows, and have drifted across repos.

This design unifies execution around a single `st-validate` command
that reads from the registry and is called by both local validation
and CI workflows.

## Design goals

1. One command — `st-validate` — serves both local pre-commit and CI.
2. All check commands are centrally defined in standard-tooling's
   command registry. No bespoke `scripts/dev/` scripts.
3. CI reusable workflows in standard-actions are thin: checkout,
   container, `st-validate --check <type>`.
4. Check names produced by CI match what `st-github-config` generates
   for branch protection rulesets.
5. Approach A sequencing: standard-tooling first (new `st-validate`
   command + registry fixes), then standard-actions (workflow
   implementations), then consumer repo re-sweep.
6. Coordinated with the publish-and-docs rationalization spec (#318):
   both specs share a single standard-tooling release that includes
   `st-validate` (this spec) and `st-version` (#318).

## Scope

**In scope:**
- `st-validate` command in standard-tooling (replaces `st-validate-local`
  chain)
- Command registry fixes (`validate_commands.py`)
- Install command registry (dependency setup per language)
- All five CI reusable workflow implementations in standard-actions
- Self-referencing CI validation in standard-actions
- Coordination with publish-and-docs rationalization (#318) for shared
  standard-tooling release (`st-version` dependency)

**Out of scope (tracked separately):**
- Rename `st-validate-local` → `st-validate` at the CLI level (entry
  point alias — cosmetic, do after the functional work)
- Consumer repo re-sweep (blocked by this work)
- Custom validation script centralization (#526, #527, #528, #531, #532,
  #543)
- Migration of registry from Python code to TOML data file (future v2.0)
- Integration test implementation (repo-specific; the reusable workflow
  defines the naming convention and `st-github-config` enforces the
  check gate, but implementation is repo-owned)
- `standards-and-conventions` repo retirement

---

## Part 1: `st-validate` command (standard-tooling)

### Interface

```
st-validate                      # run all checks: common → language-specific → custom
st-validate --check common       # common checks only
st-validate --check lint         # language-specific lint only
st-validate --check typecheck    # language-specific typecheck only
st-validate --check test         # language-specific test only
st-validate --check audit        # language-specific audit only
```

### Behavior

1. Must run inside a dev container (same `/.dockerenv` /
   `ST_IN_DEV_CONTAINER` guard as today).
2. Reads `primary_language` from `standard-tooling.toml`.
3. If `--check` is specified:
   - If `common`: run built-in common checks (repo-profile,
     markdownlint, shellcheck, yamllint) with file-discovery logic.
   - If `lint`, `typecheck`, `test`, or `audit`: look up install
     commands for the language from the registry, run them, then
     look up check commands, run them in sequence. Fail on first
     failure.
4. If no `--check` (run-all mode):
   - Run common checks.
   - If `primary_language` is set and not `none`: run install, then
     run lint → typecheck → test → audit from the registry.
   - If `scripts/bin/validate-local-custom` exists: run it.
5. Exit 0 only if all checks pass.

### What it replaces

| Current | Replaced by |
|---|---|
| `st-validate-local` (orchestrator) | `st-validate` (no `--check`) |
| `st-validate-local-common` (common checks) | `st-validate --check common` |
| `st-validate-local-python` | `st-validate --check <type>` |
| `st-validate-local-go` | `st-validate --check <type>` |
| `st-validate-local-java` | `st-validate --check <type>` |
| `st-validate-local-rust` | `st-validate --check <type>` |
| `scripts/dev/lint.sh` (per repo) | Registry lookup |
| `scripts/dev/typecheck.sh` (per repo) | Registry lookup |
| `scripts/dev/test.sh` (per repo) | Registry lookup |
| `scripts/dev/audit.sh` (per repo) | Registry lookup |

### What stays unchanged

- `st-docker-run` — host-side launcher, picks container image, calls
  `st-validate` inside it.
- `scripts/bin/validate-local-custom` — repo-specific escape hatch,
  runs in no-`--check` mode only.
- `st-finalize-repo` — calls `st-docker-run -- st-validate` (updated
  command name, same flow).

### Common checks (built-in logic)

The `common` check type is not a simple command-string lookup. It
contains file-discovery logic:

1. **repo-profile** — always runs (`st-repo-profile` function call).
2. **markdownlint** — runs if `*.md` files exist under `docs/site/`
   or `README.md` exists. Uses bundled canonical config from
   `standard_tooling.configs`. Respects `[markdownlint].ignore`
   from `standard-tooling.toml`.
3. **shellcheck** — runs if `*.sh` files or `scripts/bin/` entries
   exist under `scripts/`.
4. **yamllint** — runs if `*.yml` / `*.yaml` files exist under
   `.github/` or repo root.
5. **hadolint** — runs if `Dockerfile*` files exist.
6. **actionlint** — runs if `.github/workflows/` directory exists.

This logic is currently in `validate_local_common_container.py` and
moves into `st-validate` as the `common` check handler.

---

## Part 2: Command registry updates (standard-tooling)

### Install commands (new)

Added to `validate_commands.py` as a new concept — dependency setup
commands that run before any check.

| Language | Install commands |
|---|---|
| Python | `uv sync --frozen --group dev` |
| Go | `go mod download` |
| Ruby | `bundle install --jobs 4` |
| Rust | `cargo fetch` |
| Java | `./mvnw dependency:resolve -B` |

`docker_cache.py`'s `_WARMUP_COMMANDS` dict is replaced by a call to
the registry, eliminating the duplication.

### Check command fixes

**Python lint:**
```
ruff check src/ tests/
ruff format --check src/ tests/
```

**Python typecheck:**
```
mypy src/ tests/
ty check src tests
```

**Python test:**
```
pytest --cov=src --cov-branch --cov-fail-under=100
```

**Python audit:**
```
uv sync --check --frozen --group dev
uv lock --check
pip-audit
pip-licenses --allow-only=<standard-allowlist>
```

Changes from current registry:
- lint and typecheck now target `src/` and `tests/` (not just `src/`)
- test coverage scoped to `src` directory (not package-name-specific)
- `pip-audit` is a plain invocation (no `-r requirements.txt` args,
  per #543)

Go, Java, Ruby, and Rust registries are already correct and unchanged.

---

## Part 3: CI reusable workflows (standard-actions)

### Job structure pattern

Every language-specific CI job follows an identical structure:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v6

  - name: Run <check-type>
    run: st-validate --check <type>
```

The workflow YAML contains no language-specific logic. `st-validate`
reads the language from `standard-tooling.toml`, looks up install and
check commands from the registry, and runs them.

### Container image selection

Each version-matrixed job uses the language-specific dev container:

```yaml
container: ghcr.io/wphillipmoore/dev-${{ (inputs.language == 'shell' || inputs.language == 'none') && 'base' || inputs.language }}:${{ matrix.version }}
```

For `shell` and `none` languages the expression resolves to
`dev-base`; for all other languages it resolves to
`dev-<language>`. Language-independent jobs (common, version-bump)
hardcode `ghcr.io/wphillipmoore/dev-base:latest`.

Container images have `st-validate` pre-installed (standard-tooling
is installed in the dev container images built by
standard-tooling-docker).

### ci-quality.yml

**Inputs:** `language` (string, required), `versions` (JSON array,
required)

**Jobs:**

| Job | Matrix | Container | Command | Check name |
|---|---|---|---|---|
| `common` | none | `dev-base:latest` | `st-validate --check common` | `quality / common` |
| `lint / <ver>` | versions | `dev-<lang>:<ver>` | `st-validate --check lint` | `quality / lint / <ver>` |
| `typecheck / <ver>` | versions | `dev-<lang>:<ver>` | `st-validate --check typecheck` | `quality / typecheck / <ver>` |

`lint` and `typecheck` jobs always run, regardless of whether the
language has registry entries for that check type. When there are no
commands, `st-validate` exits 0 with a message like "no lint commands
for language 'shell'". This avoids conditional complexity in the
workflow YAML and produces harmless phantom checks that
`st-github-config` simply does not require. The no-op jobs also serve
as natural placeholders that get filled in as tooling matures for each
language.

### ci-test.yml

**Inputs:** `language` (string, required), `versions` (JSON array,
required)

**Jobs:**

| Job | Matrix | Container | Command | Check name |
|---|---|---|---|---|
| `unit / <ver>` | versions | `dev-<lang>:<ver>` | `st-validate --check test` | `test / unit / <ver>` |

Integration tests are not included in the reusable workflow.
Investigation of all five mq-rest-admin language repos showed that
integration test patterns are uniform within a product family (same
setup action, same env vars, same matrix structure) but the service
provisioning and port allocation are product-specific and cannot be
generalized into a reusable workflow.

Integration test support works through the naming convention:
`st-github-config` generates required status checks
(`test / integration / <ver>`) when a repo declares integration
tests. The implementation is repo-local — repos define their own
integration job in their ci.yml with whatever setup they need, as
long as the check name matches the convention.

### ci-audit.yml

**Inputs:** `language` (string, required), `versions` (JSON array,
required)

**Jobs:**

| Job | Matrix | Container | Command | Check name |
|---|---|---|---|---|
| `dependencies / <ver>` | versions | `dev-<lang>:<ver>` | `st-validate --check audit` | `audit / dependencies / <ver>` |

### ci-release.yml

**Inputs:** `language` (string, required), `run-release` (boolean,
default: true)

**Jobs:**

| Job | Matrix | Container | Command | Check name |
|---|---|---|---|---|
| `version-bump` | none | `dev-base:latest` | `version-divergence` action | `release / version-bump` |

Uses the existing `actions/release-gates/version-divergence` composite
action with `st-version show` as the version commands. The action's
generic interface (accepting shell commands for version extraction) is
preserved. The workflow passes `st-version show` as the
`head-version-command` and `st-version show --ref origin/main` as the
`main-version-command`. The `--ref` argument reads the version file
via `git show <ref>:<path>` instead of the filesystem, avoiding any
worktree or checkout manipulation.
`st-version` is defined in the publish-and-docs rationalization spec
(#318) and is included in the shared standard-tooling release.

No version matrix. Skipped when `run-release` is false.

### ci-security.yml

**No changes.** Already fully implemented.

### ci.yml (self-referencing orchestrator)

Standard-actions is a `shell` language repo. Its orchestrator calls:

```yaml
jobs:
  quality:
    uses: ./.github/workflows/ci-quality.yml
    with:
      language: shell
      versions: '["latest"]'

  security:
    uses: ./.github/workflows/ci-security.yml
    permissions:
      contents: read
      security-events: write
    with:
      language: shell
      run-codeql: false

  release:
    uses: ./.github/workflows/ci-release.yml
    with:
      language: shell
```

Since `shell` has no lint, typecheck, test, or audit entries in the
registry, only `quality / common`, security jobs, and
`release / version-bump` run. This is correct.

Does not call `ci-test.yml` or `ci-audit.yml` (no tests or auditable
dependencies for a shell/YAML repo).

### Dependency: `st-version` (from #318)

The ci-release.yml workflow depends on `st-version show` from the
publish-and-docs rationalization spec (#318). Both specs share a
single standard-tooling release: `st-validate` + registry updates
(this spec) and `st-version` + `[publish]` config (#318) ship
together before either spec's standard-actions phase can proceed.

---

## Part 4: Consumer repo pattern (post-reset)

After both standard-tooling and standard-actions changes land,
consumer repos become thin callers. Example for a Python repo:

```yaml
# .github/workflows/ci.yml
name: CI
on:
  pull_request:

permissions:
  contents: read
  security-events: write

jobs:
  quality:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-quality.yml@v1.6
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  test:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-test.yml@v1.6
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  audit:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-audit.yml@v1.6
    with:
      language: python
      versions: '["3.12", "3.13", "3.14"]'

  security:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-security.yml@v1.6
    permissions:
      contents: read
      security-events: write
    with:
      language: python

  release:
    uses: wphillipmoore/standard-actions/.github/workflows/ci-release.yml@v1.6
    with:
      language: python
```

All bespoke CI jobs are removed. All `scripts/dev/` scripts are
removed. The repo's CI is fully driven by the reusable workflows.

---

## Part 5: Implementation sequence (Approach A)

### Phase 1: standard-tooling (combined with #318)

This phase is coordinated with the publish-and-docs rationalization
spec (#318). Both specs' standard-tooling work ships in a single
release.

**From this spec:**

1. Fix `validate_commands.py` registry (lint/typecheck/test/audit
   corrections, add install commands).
2. Build `st-validate` command (new module, reads config, dispatches
   to registry and common checks including hadolint and actionlint).
3. Wire `docker_cache.py` to read install commands from registry
   instead of `_WARMUP_COMMANDS`.
4. Update `st-finalize-repo` to call `st-validate` instead of
   `st-validate-local`.

**From #318:**

5. Build `st-version` library and CLI (`show`, `show --major-minor`,
   `bump` with per-language version discovery and lockfile maintenance).
6. Extend config schema with `[publish]` section.
7. Extend `st-github-config` for publish validation.

**Combined:**

8. Tests, validation, release as a single standard-tooling version.

### Phase 2: standard-actions

6. Implement ci-quality.yml (common + lint + typecheck jobs).
7. Implement ci-test.yml (unit job; integration deferred).
8. Implement ci-audit.yml (dependencies job).
9. Implement ci-release.yml (version-bump job using existing action).
10. Validate self-referencing CI passes.
11. Release as standard-actions v1.6.

### Phase 3: consumer re-sweep

12. Update each consumer repo: replace bespoke CI with thin wrappers,
    remove `scripts/dev/` scripts, pin to standard-actions v1.6.
13. Start with mq-rest-admin-python (where the problems were found),
    then ai-research-methodology, then remaining repos.

---

## Deprecation plan

After consumer re-sweep is complete:

- `st-validate-local`, `st-validate-local-common`,
  `st-validate-local-python`, etc. — deprecated, emit a warning
  pointing to `st-validate`. Remove in standard-tooling v2.0.
- `scripts/dev/{lint,typecheck,test,audit}.sh` — no longer needed.
  `st-validate-local-<lang>` (if still called) ignores them in
  favor of the registry.
- `_WARMUP_COMMANDS` in `docker_cache.py` — replaced by registry
  lookup.
- `validate_local_*.sh` in `standards-and-conventions` — retired
  with the repo.

## Future considerations (out of scope)

- Migrate command registry from Python code to a TOML data file for
  easier management and potential per-repo overrides.
- Integration test interface standardization.
- `st-validate` version matrix support for local development (run
  checks across multiple versions locally via Docker).
