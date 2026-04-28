# Publish workflow ordering

Each consuming repository has a `publish.yml` workflow that runs on push to
`main`. While the specific build, publish, and version-bump steps are
language-specific, the **ordering of phases** must be consistent across all
repositories.

## Table of Contents

- [Canonical step order](#canonical-step-order)
- [Why this order matters](#why-this-order-matters)
- [Gating the registry publish step](#gating-the-registry-publish-step)
- [Go exception](#go-exception)
- [Version bump PR](#version-bump-pr)
- [Idempotency gates](#idempotency-gates)

## Canonical step order

```text
1. Checkout + language setup
2. Extract version from source
3. Check if tag already exists          (idempotency gate)
4. Check if already on public registry  (idempotency gate, language-specific)
5. Build and validate
6. Attest build provenance
7. Generate SBOM
8. Tag and release                      (GitHub tag + release with artifacts)
9. Publish to public registry           (optional, gated on credentials)
10. Version bump PR                     (bumps version on develop)
```

## Why this order matters

Steps 1-8 use only GitHub-native capabilities (tags, releases, attestations)
and shared actions. They must always succeed when a new version is merged to
main.

Step 9 (publishing to PyPI, Maven Central, RubyGems, etc.) depends on external
credentials and services. If it runs before tagging:

- A registry outage or credential issue blocks the entire release pipeline
- No tag is created, so the docs site has no release content
- No version bump PR is filed, so develop falls out of sync
- The SBOM is never generated or attached to a release

By placing the registry publish **after** the tag, the release is recorded in
GitHub regardless of whether the external publish succeeds. The publish step
can be re-run manually or the next push to main will pick it up via the
idempotency gates.

## Gating the registry publish step

The publish step should be gated on **both** the idempotency check (is this
version already published?) and credential availability.

**Important**: The `secrets` context is not reliably available in step-level
`if:` conditions. To gate on a secret, declare a job-level `env` variable
that evaluates the secret in an expression context (where secrets **are**
available), then reference the env var in the step condition:

```yaml
jobs:
  publish:
    runs-on: ubuntu-latest
    env:
      # Evaluated in expression context where secrets are available.
      # Produces 'true' or 'false' as a string.
      HAS_REGISTRY_KEY: ${{ secrets.REGISTRY_API_KEY != '' }}
    steps:
      # ... build, attest, SBOM, tag steps ...

      # Secret-based credentials (Ruby, Java)
      - name: Publish to registry
        if: steps.registry_check.outputs.status == 'not_found' && env.HAS_REGISTRY_KEY == 'true'
        env:
          REGISTRY_API_KEY: ${{ secrets.REGISTRY_API_KEY }}
        run: publish-command

      # OIDC trusted publishing (Python)
      - name: Publish to PyPI
        if: steps.pypi_check.outputs.status == 'not_found'
        uses: pypa/gh-action-pypi-publish@release/v1
```

For languages using OIDC trusted publishing (Python/PyPI), the secret gate is
not needed because the action uses GitHub's built-in OIDC provider.

For languages using explicit API keys or credentials, gate on the secret so that
repositories without credentials configured can still tag releases and file
version bump PRs.

## Go exception

Go modules are published by pushing a tag — there is no separate publish step.
The Go workflow naturally has the correct order because `tag-and-release` is the
publish mechanism.

## Version bump PR

The `version-bump-pr` action computes the next patch version, creates a branch
from develop that merges main, updates the version file, and opens a PR. The
release workflow agent drives the merge via `st-merge-when-green`. Key
configuration points:

### Regex quoting

The action interpolates `version-regex` into a Python raw string `r'...'`.
Single quotes in the regex will break the Python string. Use `\x27` (regex hex
escape) instead of literal `'`:

```yaml
# Wrong — single quotes conflict with Python r'...' wrapper
version-regex: "(VERSION\\s*=\\s*').*(')"

# Correct — \x27 is interpreted by the regex engine as '
version-regex: '(VERSION\s*=\s*\x27).*(\x27)'
```

Double quotes work naturally since Go and Python use them:

```yaml
version-regex: '(Version\s*=\s*\").*(\"\s*)'
```

### Lock file updates

Languages with lock files (Ruby's `Gemfile.lock`, Python's `uv.lock`) must
include `post-bump-command` and `extra-files` so the lock file stays in sync:

```yaml
# Ruby
post-bump-command: bundle lock --update mq-rest-admin
extra-files: Gemfile.lock

# Python
post-bump-command: uv lock --upgrade && uv export --no-hashes -o requirements.txt
extra-files: uv.lock requirements.txt requirements-dev.txt
```

## Idempotency gates

Every step should be safe to re-run. The two gates ensure this:

- **Tag check**: Skips everything if the tag already exists (the release was
  already created on a previous run)
- **Registry check**: Skips the publish step if the version is already on the
  public registry (avoids duplicate publish errors)

Build, attest, and SBOM steps should be gated on `tag_check` (not the registry
check) because these artifacts are needed for the GitHub release regardless of
registry status.
