# Alignment Review: Extract inline workflow logic into composite actions

**Date:** 2026-05-10
**Commit:** 1089c2c

## Documents Reviewed

- **Intent:** `docs/superpowers/specs/2026-05-09-extract-workflow-logic-design.md`
- **Action:** `docs/plans/2026-05-10-extract-workflow-logic.md`
- **Design:** None separate (design decisions embedded in spec)

## Source Control Conflicts

None — no conflicts with recent changes. Both documents were written against
the current codebase state (post-#383 workflow renames, post-#412/#414
registry-publish flag, post-#418 system Python fix).

## Issues Reviewed

### [1] Spec's security constraint doesn't address `eval` — plan uses it correctly but undocumented
- **Category:** Design gap (spec omission, plan resolves correctly)
- **Severity:** Minor
- **Documents:** Spec security constraint (line 174) vs plan Task 2 Steps 5-6
- **Issue:** The spec mandates `env:` over `${{ }}` interpolation but doesn't
  address how to execute commands stored in env vars. The plan uses
  `eval "$BUILD_CMD"` and `eval "$PUBLISH_CMD"` — necessary because commands
  like `uv publish dist/*` contain shell globs that require expansion. Without
  `eval`, the glob would be passed as a literal string. The plan is correct
  but the spec didn't document this companion pattern.
- **Resolution:** Added a note to the spec's security constraint explaining
  that `eval` on env vars is the expected execution mechanism, and that it's
  safe because the `env:` boundary prevents injection at the
  shell-interpolation layer.

### [2] Build audits coupled to registry-publish flag — Go gets lower audit bar
- **Category:** Design gap (architectural coupling)
- **Severity:** Important
- **Documents:** Spec resulting workflow shape (step 7 condition) vs actual
  release semantics for Go
- **Issue:** The build/attestation/SBOM pipeline was gated on
  `inputs.registry-publish`, meaning it only ran when a caller explicitly
  opted into registry publishing. For Go, publishing happens implicitly via
  git tag (`tag-and-release` step), which runs unconditionally. This meant
  Go releases could reach end users without build verification, attestation,
  or SBOM generation — a lower audit bar than Python/Rust/Ruby/Java.

  Additionally, the `language` input has a broader namespace than
  "programming languages with build pipelines" — values like `shell`,
  `claude-plugin`, and `base` don't have meaningful build semantics. Gating
  on `language != base` would incorrectly trigger the build pipeline for
  these non-buildable project types.
- **Resolution:** Decoupled the two concerns:
  1. **Build auditing** (build, attestation, SBOM) now runs for all supported
     build languages (`python`, `java`, `ruby`, `rust`, `go`) when a new tag
     is being created — regardless of the `registry-publish` flag.
  2. **Registry publishing** (the final push-to-registry step) is gated on
     `registry-publish: true` inside the action.
  3. The workflow gate uses positive inclusion
     (`contains(fromJSON('[...]'), inputs.language)`) rather than negative
     exclusion (`!= base`), ensuring only languages with actual build
     semantics trigger the pipeline.
  4. A `registry-publish` boolean input was added to the `registry-publish`
     action so it can gate the final publish step internally.
  5. The broader naming concern (`language` serving dual purposes,
     `registry-publish` naming being misleading for Go) was noted in #440
     for the namespace rationalization effort.

## Unresolved Issues

None — all issues addressed.

## Detailed Coverage Matrix

### Spec Requirements → Plan Tasks

| Spec Requirement | Plan Coverage | Notes |
|-----------------|---------------|-------|
| `validate-inputs` check 1 (container-tag) | Task 1, lines 69-73 | Exact match |
| `validate-inputs` check 2 (base + registry-publish) | Task 1, lines 75-79 | Exact match |
| `validate-inputs` check 3 (supported language) | Task 1, lines 81-93 | Exact match, all 5 languages |
| `registry-publish` env: security constraint | Task 2, all steps | Every shell step uses env: |
| `registry-publish` 5 languages in derivation | Task 2, Step 2 | python, rust, ruby, java, go |
| `registry-publish` default case guard | Task 2, Step 2, lines 203-206 | Fails with ::error |
| `registry-publish` Maven credential provisioning | Task 2, Step 3 | java-only conditional |
| `registry-publish` version placeholder resolution | Task 2, Step 4 | $VERSION in sbom-output-file |
| `registry-publish` build step | Task 2, Step 5 | Conditional on non-empty command |
| `registry-publish` attestation | Task 2, Step 5 | Conditional on subject-path |
| `registry-publish` SBOM | Task 2, Step 5 | Conditional on output-file |
| `registry-publish` single publish path | Task 2, Step 6 | Credential guard + eval |
| `registry-publish` pipeline gated on language set | Task 3, Step 2 | contains(fromJSON(...)) |
| `registry-publish` publish gated on flag | Task 2, Step 6 | inputs.registry-publish == 'true' |
| `registry-publish` outputs (3) | Task 2, Step 1 | build-command, publish-command, sbom-output-file |
| `freeze-internal-refs` git identity | Task 4, Step 1 | github-actions[bot] |
| `freeze-internal-refs` sed restricted to uses: | Task 4, Step 1 | /uses:/s pattern |
| `freeze-internal-refs` two sed passes | Task 4, Step 1 | ./actions/ and @develop |
| `freeze-internal-refs` validation | Task 4, Step 1 | grep + ::error annotations |
| `freeze-internal-refs` conditional commit | Task 4, Step 1 | git diff --quiet guard |
| `docs-deploy` default changed to "" | Task 6, Step 1 | Exact match |
| `docs-deploy` auto-detect via tomllib | Task 6, Step 2 | /usr/local/bin/python3 |
| `docs-deploy` python → uv run mike | Task 6, Step 2 | Conditional logic |
| `docs-deploy` backward compatible | Task 6, Steps 1-2 | Non-empty input used as-is |
| `cd-release.yml` resulting shape | Task 3 | All 10 steps accounted for |
| `cd.yml` resulting shape | Task 5 | All 7 steps accounted for |
| `cd-docs.yml` resulting shape | Task 7 | All 4 steps accounted for |
| 3 implementation phases | Tasks 1-3, 4-5, 6-7 | Independently shippable |
| Name mapping (registry-publish-command → publish-command) | Task 3, Step 2 | publish-command: ${{ inputs.registry-publish-command }} |

### Plan Tasks → Spec Requirements (Scope Compliance)

| Plan Task | Spec Requirement | In Scope? |
|-----------|-----------------|-----------|
| Task 1: validate-inputs | Spec §validate-inputs | Yes |
| Task 2: registry-publish | Spec §registry-publish | Yes |
| Task 3: Rewrite cd-release.yml | Spec §resulting workflow shapes | Yes |
| Task 4: freeze-internal-refs | Spec §freeze-internal-refs | Yes |
| Task 5: Rewrite cd.yml | Spec §resulting workflow shapes | Yes |
| Task 6: Modify docs-deploy | Spec §docs-deploy modification | Yes |
| Task 7: Simplify cd-docs.yml | Spec §resulting workflow shapes | Yes |
| Task 8: Final validation | Implicit (spec §Testing) | Yes — reasonable implementation step |

### Design Decisions Reflected in Plan

| Decision | Plan Implementation |
|----------|-------------------|
| #1 Merged publish pipeline | Task 2 is one action with all steps |
| #2 Standalone input validation | Task 1 is separate from Task 2 |
| #3 Atomic ref freezing | Task 4 combines freeze + validate + commit |
| #4 Auto-detect in docs-deploy | Task 6 adds detection to existing action |
| #5 Explicit secret inputs | Task 2 Step 1 declares all credential inputs |
| #6 env: over ${{ }} | All plan shell steps use env: pattern |

## Alignment Summary

- **Requirements:** 29 checked, 29 covered, 0 gaps
- **Tasks:** 8 total, 8 in scope, 0 orphaned
- **Design decisions:** 6 total, 6 reflected in plan
- **Status:** Aligned — ready for implementation
