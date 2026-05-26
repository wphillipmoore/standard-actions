# Container-Suffix Defaults and Language Namespace Rationalization

**Issue:** #560
**Date:** 2026-05-26
**Status:** Approved

## Problem

Commit d7b632c8 changed the default `container-suffix` inline fallback in
ci-audit.yml and ci-test.yml from `inputs.language` to `'base'`. This
produced invalid image references (`prod-base:1.25`) for language repos and
forced a CI sweep adding explicit `container-suffix: <language>` overrides
to every consumer.

The deeper issue: `shell`, `claude-plugin`, and `none` exist as `language`
values but trigger no unique workflow behavior. They require callers to
manually override container selection, disable CodeQL, and skip
audit/test — ceremony that could be eliminated by making `language`
optional.

## Current State

### Inline fallback patterns

| Workflow | Job | Current fallback | Correct fallback |
|---|---|---|---|
| ci-quality | common | `'base'` | `'base'` (no change) |
| ci-quality | lint | `inputs.language` | `inputs.language` (no change) |
| ci-quality | typecheck | `inputs.language` | `inputs.language` (no change) |
| ci-audit | dependencies | `'base'` | `inputs.language` |
| ci-test | unit | `'base'` | `inputs.language` |
| ci-version-bump | version-bump | `'base'` | `'base'` (no change) |
| ci-security | standards | `'base'` | `'base'` (no change) |
| ci-security | semgrep | hardcoded `base` | hardcoded `base` (no change) |
| cd-release | release | `inputs.language` (default `"base"`) | `inputs.language \|\| 'base'` (default `""`) |

### Consumer override analysis

Every language repo (6 of 6) passes explicit `container-suffix` to ci-audit
and ci-test — a 100% override rate confirming the default is wrong.

Non-language repos (vergil-actions, vergil-docker, vergil-vm,
vergil-claude-plugin, .github) never call ci-audit or ci-test and manually
override everything else to `base`.

### Language values in use

| Value | Repos | Triggers unique workflow behavior? |
|---|---|---|
| `python` | vergil-tooling, mq-rest-admin-python | Yes (container, dep install, build/publish) |
| `go` | mq-rest-admin-go | Yes (container, build/publish) |
| `java` | mq-rest-admin-java | Yes (container, Maven/GPG, build/publish) |
| `ruby` | mq-rest-admin-ruby | Yes (container, build/publish) |
| `rust` | mq-rest-admin-rust | Yes (container, build/publish) |
| `shell` | vergil-actions, vergil-docker, vergil-vm | No — bypassed via overrides |
| `claude-plugin` | vergil-claude-plugin | No — bypassed via overrides |
| `none` | .github | No — bypassed via overrides |

## Design

### Approach: Fix defaults + make `language` optional

Make `language` optional across all reusable workflows. When omitted,
workflows run only language-agnostic checks. When provided, it should be a
real language (python, go, java, ruby, rust) and drives container selection,
conditional steps, and build/publish behavior. No runtime validation is
added (that was Approach C) — passing an unsupported value fails at
container pull time, which is a clear enough signal.

### Changes to vergil-actions workflows

#### ci-audit.yml

- Change `language` from `required: true` to `required: false`.
- Change inline fallback from `|| 'base'` to `|| inputs.language`.
- Update input description.
- No `if` guard added — callers without a language should not invoke
  ci-audit. If called without `language`, the container expression
  resolves to an invalid image name and fails at pull time (fail-fast).

#### ci-test.yml

- Change `language` from `required: true` to `required: false`.
- Change inline fallback from `|| 'base'` to `|| inputs.language`.
- Update input description.
- Same fail-fast contract as ci-audit.

#### ci-quality.yml

- Change `language` from `required: true` to `required: false`.
- Add `if: inputs.language != ''` to lint and typecheck jobs.
- `versions` stays `required: true` for interface consistency. Non-language
  repos pass `'["latest"]'` — the value is unused when lint/typecheck are
  skipped, but keeping it required avoids a second interface change.
- Update input description.

#### ci-security.yml

- Change `language` from `required: true` to `required: false`.
- Add `inputs.language != ''` to the CodeQL job condition (alongside
  existing `run-security` and `run-codeql` checks).
- Update input description.

#### ci-version-bump.yml

- Change `language` from `required: true` to `required: false`.
- Update input description.

#### cd-release.yml

- Change `language` default from `"base"` to `""`.
- Change container expression to `${{ inputs.language || 'base' }}`.
- Update `validate-inputs` action to treat empty language the same as
  `"base"`:
  - Check 1 (container-tag guard): currently rejects when language is
    not `"base"` and container-tag is `"latest"`. Add `|| [ -z
    "$INPUT_LANGUAGE" ]` so empty language passes the same way `"base"`
    does.
  - Check 2 (registry-publish guard): currently rejects when
    registry-publish is true and language is `"base"`. Add `|| [ -z
    "$INPUT_LANGUAGE" ]` so empty language is also rejected for
    publishing.

### Consuming repo cleanup (follow-up sweep)

#### Language repos

Remove all `container-suffix` and `container-tag` overrides. Keep only
`language` and `versions`:

```yaml
# Before (mq-rest-admin-go)
audit:
  uses: vergil-project/vergil-actions/.github/workflows/ci-audit.yml@v2.0
  with:
    language: go
    versions: '["1.25", "1.26"]'
    container-suffix: go

# After
audit:
  uses: vergil-project/vergil-actions/.github/workflows/ci-audit.yml@v2.0
  with:
    language: go
    versions: '["1.25", "1.26"]'
```

#### Non-language repos

Remove `language`, `container-suffix`, `container-tag`, and
`run-codeql: false`:

```yaml
# Before (vergil-actions)
quality:
  uses: ./.github/workflows/ci-quality.yml
  with:
    language: shell
    versions: '["latest"]'
    container-suffix: base
    container-tag: 'latest'

security:
  uses: ./.github/workflows/ci-security.yml
  with:
    language: shell
    run-codeql: false
    container-suffix: base
    container-tag: 'latest'

# After
quality:
  uses: ./.github/workflows/ci-quality.yml
  with:
    versions: '["latest"]'

security:
  uses: ./.github/workflows/ci-security.yml
```

### Sequencing

1. **Phase 1:** Ship workflow changes in vergil-actions (backwards-compatible
   — existing callers with explicit overrides continue to work).
2. **Phase 2:** Sweep consuming repos to remove redundant parameters once
   the new vergil-actions release is tagged.

### Scope boundary

- `vergil.toml` `primary-language` values are **not changed**. The tooling
  (vrg-version, vrg-validate) keeps its own taxonomy for version file
  location and validation dispatch. That concern is independent of the
  workflow interface.
- The `container-suffix` and `container-tag` inputs remain available for
  edge cases where a caller needs to override container selection. They
  just stop being required for the common case.

## Not Changed

- Semgrep action — already handles empty language gracefully.
- `registry-publish` action — gated by `contains(...)` check which
  naturally excludes empty strings.
- ci-quality common job — already defaults to `base`.
- ci-version-bump — already defaults to `base`.
