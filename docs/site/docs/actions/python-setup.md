# python/setup

Sets up Python and uv with dependency caching.

## Usage

```yaml
- uses: wphillipmoore/standard-actions/actions/python/setup@v1.5
  with:
    python-version: "3.14"
    uv-version: "0.10.7"
```

## Inputs

| Name | Required | Default | Description |
| ------ | ---------- | --------- | ------------- |
| `python-version` | **Yes** | — | Python version to install (e.g. `3.14`). |
| `uv-version` | No | `0.10.7` | uv version to install. |

## Permissions

- `contents: read` (default)

## Behavior

1. **Set up Python** — Uses `actions/setup-python@v6` to install the specified
   Python version.
2. **Install uv** — Uses `astral-sh/setup-uv@v8` to install the pinned version
   of uv and configure dependency caching automatically.

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

## GitHub configuration

No special repository configuration is required.
