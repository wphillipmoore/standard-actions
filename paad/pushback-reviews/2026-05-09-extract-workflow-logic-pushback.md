# Pushback Review: Extract inline workflow logic into composite actions

**Date:** 2026-05-09
**Spec:** docs/superpowers/specs/2026-05-09-extract-workflow-logic-design.md
**Commit:** 468173f

## Source Control Conflicts

None — no conflicts with recent changes. The spec was written against the
current state (post-#383 workflow renames, post-#412/#414 registry-publish
flag, post-#418 system Python fix).

## Issues Reviewed

### [1] Expression injection in command override inputs
- **Category:** Security
- **Severity:** Serious
- **Issue:** `build-command` and `publish-command` override inputs used via
  `${{ }}` expression interpolation in `run:` blocks creates an expression
  injection surface. Inherited from the current code but the extraction
  widens the trust boundary by making this a reusable action.
- **Resolution:** Require `env:` variables for all input-to-shell passing.
  Added as design decision #6 and as a security constraint in the
  `registry-publish` action specification.

### [2] Unsupported language silently produces empty commands
- **Category:** Omission
- **Severity:** Moderate
- **Issue:** Neither `validate-inputs` nor `registry-publish` validates that
  `language` is one of the supported ecosystems (python, java, ruby, rust,
  go). A caller could pass an unsupported language with
  `registry-publish: true`, pass validation, and have the publish pipeline
  silently skip everything.
- **Resolution:** Add supported-language check to `validate-inputs` when
  `registry-publish` is true. Add a default-case guard in
  `registry-publish`'s case statement as defense in depth. The supported
  set is maintained as a single, easily extensible list.

### [3] Python publish path ambiguously described
- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The spec described two different flows for Python publishing —
  the command derivation table showed a publish command, but step 8
  special-cased Python separately from the credential-guarded flow. Unclear
  whether overrides are respected for Python.
- **Resolution:** Single publish path for all languages. The resolved
  publish command (derived or overridden) is always used. The credential
  guard is conditional on whether the language defines a credential secret.
  No special-case Python flow.

### [4] `freeze-internal-refs` sed patterns over-match
- **Category:** Feasibility
- **Severity:** Minor
- **Issue:** Sed patterns match `./actions/` and `@develop` anywhere in a
  line, including in YAML comments and strings. Pre-existing behavior but
  being extracted to a reusable action.
- **Resolution:** Tighten sed to only rewrite lines matching `uses:`.

### [5] Action namespace coherence
- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** The `actions/` directory namespace has grown organically and
  doesn't consistently map back to the workflow hierarchy. The workflow
  input `registry-publish-command` maps to the action input
  `publish-command` without documentation.
- **Resolution:** Added a name-mapping note to the spec. Broader namespace
  rationalization deferred to #440.

## Unresolved Issues

None — all issues addressed.

## Summary

- **Issues found:** 5
- **Issues resolved:** 5
- **Unresolved:** 0
- **Spec status:** Ready for implementation
