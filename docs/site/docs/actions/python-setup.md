# python/setup

Sets up Python, installs uv, and configures dependency caching.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/python/setup@v1.5
  with:
    python-version: "3.14"
    uv-version: "0.10.7"
    cache-prefix: "uv"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `python-version` | **Yes** | — | Python version to install (e.g. `3.14`). |
| `uv-version` | No | `0.10.7` | uv version to install. |
| `cache-prefix` | No | `uv` | Cache key prefix for uv dependency cache. |

## Permissions

- `contents: read` (default)

## Behavior

1. **Set up Python** — Uses `actions/setup-python@v6` to install the specified
   Python version.
2. **Install uv** — Runs `pip install uv==<version>` to install the pinned
   version of uv.
3. **Cache dependencies** — Uses `actions/cache@v5` to cache `~/.cache/uv`.
   The cache key includes the OS, Python version, and a hash of `uv.lock` for
   precise invalidation.

## Examples

### Basic Python setup

```yaml
- uses: actions/checkout@v6
- uses: wphillipmoore/standard-actions/actions/python/setup@v1.5
  with:
    python-version: "3.14"
- run: uv sync
- run: uv run pytest
```

### Custom cache prefix for multiple Python versions

```yaml
- uses: wphillipmoore/standard-actions/actions/python/setup@v1.5
  with:
    python-version: "3.13"
    cache-prefix: "uv-py313"
```

## GitHub configuration

No special repository configuration is required.
