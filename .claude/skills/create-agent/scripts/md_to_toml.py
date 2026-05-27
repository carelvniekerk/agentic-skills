#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-frontmatter",
#     "tomli-w",
# ]
# ///
# Note: tomllib is in the stdlib from Python 3.11+; no separate dep needed for reads.
"""Transpile an Anthropic-style agent .md into a Codex agent .toml sibling.

Reads a Markdown agent definition (YAML frontmatter + system-prompt body) and
emits a Codex-compatible TOML file in the same directory.

Mapping:
    YAML ``name``          → TOML ``name`` (string)
    YAML ``description``   → TOML ``description`` (string)
    markdown body          → TOML ``developer_instructions`` (multi-line string)
    YAML ``model``         → TOML ``model`` (string, if present)

Codex-only fields (``nickname_candidates``, ``model_reasoning_effort``,
``sandbox_mode``, ``mcp_servers``, ``model``, ``skills.config``) are authored
**directly in the existing target ``.toml``** — when this script runs and the
target already exists, it parses the existing TOML and preserves every key other
than the three managed fields (``name``, ``description``,
``developer_instructions``), which are always re-derived from the ``.md``.
This means hand-added Codex-only fields survive a re-transpile.

The canonical ``.md`` frontmatter in this repo is limited to ``name`` and
``description`` only — Claude-specific fields (``tools``, ``model``,
``permissionMode``, ``color``, etc.) live in ``.harness/claude.yaml`` and are
not consulted when generating the ``.toml``.

Usage:
    uv run md_to_toml.py path/to/agent.md
    uv run md_to_toml.py path/to/agent.md --output path/to/agent.toml
"""

import argparse
import sys
import tomllib
from pathlib import Path

import frontmatter
import tomli_w

MANAGED_KEYS = ("name", "description", "developer_instructions")


def transpile(md_path: Path, toml_path: Path) -> None:
    """Read ``md_path`` and write a Codex-compatible ``toml_path``.

    If ``toml_path`` already exists, every key other than the three managed
    fields (``name``, ``description``, ``developer_instructions``) is
    preserved, so hand-added Codex-only fields survive a re-transpile.
    """
    post = frontmatter.load(md_path)
    meta = post.metadata
    body = post.content.strip()

    name = meta.get("name") or md_path.stem
    description = meta.get("description")
    if not description:
        raise ValueError(f"{md_path} is missing required 'description' frontmatter")
    if not body:
        raise ValueError(f"{md_path} has an empty body; Codex needs developer_instructions")

    existing: dict[str, object] = {}
    if toml_path.exists():
        existing = tomllib.loads(toml_path.read_text())

    out: dict[str, object] = {
        key: value for key, value in existing.items() if key not in MANAGED_KEYS
    }
    out["name"] = str(name)
    out["description"] = str(description).strip()
    out["developer_instructions"] = body

    ordered: dict[str, object] = {
        "name": out.pop("name"),
        "description": out.pop("description"),
        "developer_instructions": out.pop("developer_instructions"),
        **out,
    }

    toml_path.write_bytes(tomli_w.dumps(ordered).encode())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("md_path", type=Path, help="Path to the Anthropic-style agent .md")
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=None,
        help="Output .toml path (defaults to md_path with .toml suffix)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    md_path: Path = args.md_path
    if not md_path.is_file():
        print(f"error: {md_path} is not a file", file=sys.stderr)
        return 1
    toml_path: Path = args.output or md_path.with_suffix(".toml")
    transpile(md_path, toml_path)
    print(f"wrote {toml_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
