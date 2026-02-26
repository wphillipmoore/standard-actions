"""Generate releases/index.md with a version table sorted by semver descending."""

import pathlib
import re
import sys

release_dir = pathlib.Path(sys.argv[1]) / "releases"
files = sorted(
    release_dir.glob("v*.md"),
    key=lambda f: [int(x) for x in re.findall(r"\d+", f.stem)],
    reverse=True,
)

lines = ["# Release Notes", "", "| Version | Date |", "|---------|------|"]
for f in files:
    stem = f.stem
    version = stem.lstrip("v")
    text = f.read_text()
    m = re.search(r"\d{4}-\d{2}-\d{2}", text[:200])
    date = m.group(0) if m else ""
    lines.append(f"| [{version}]({stem}.md) | {date} |")

(release_dir / "index.md").write_text("\n".join(lines) + "\n")
