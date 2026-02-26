"""Patch mkdocs.yml nav to inject release version entries under Release Notes."""

import pathlib
import re
import sys

import yaml

config_path = pathlib.Path(sys.argv[1])
docs_dir = pathlib.Path(sys.argv[2]) / "releases"

# Collect version files sorted by semver descending
versions = sorted(
    [f.stem for f in docs_dir.glob("v*.md")],
    key=lambda s: [int(x) for x in re.findall(r"\d+", s)],
    reverse=True,
)

config = yaml.safe_load(config_path.read_text())
nav = config.get("nav", [])

# Find the Releases section
for i, item in enumerate(nav):
    if isinstance(item, dict) and "Releases" in item:
        release_entries = [
            {"Changelog": "changelog.md"},
            {
                "Release Notes": [
                    "releases/index.md",
                    *[{v: f"releases/{v}.md"} for v in versions],
                ]
            },
        ]
        nav[i] = {"Releases": release_entries}
        break

config["nav"] = nav
config_path.write_text(yaml.dump(config, default_flow_style=False, sort_keys=False))
