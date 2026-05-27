#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-frontmatter",
#     "tomli-w",
# ]
# ///
"""Transpile an Anthropic-style agent .md into a Codex agent .toml sibling.

Reads a Markdown agent definition (YAML frontmatter + system-prompt body) and
emits a Codex-compatible TOML file in the same directory.

Mapping:
    YAML ``name``          → TOML ``name`` (string)
    YAML ``description``   → TOML ``description`` (string)
    markdown body          → TOML ``developer_instructions`` (multi-line string)
    YAML ``model``         → TOML ``model`` (string, if present)

Codex-only fields (``nickname_candidates``, ``model_reasoning_effort``,
``sandbox_mode``, ``mcp_servers``, ``skills.config``) are read from a top-level
``codex:`` YAML block in the frontmatter, if present, and copied verbatim into
the TOML output. Anthropic-only fields (``tools``, ``color``, ``permissionMode``,
``disallowedTools``, ``mcpServers``, ``hooks``, ``permissionMode``, ``memory``,
``background``, ``isolation``, ``maxTurns``, ``effort``, ``initialPrompt``,
``skills``) are dropped — they have no Codex equivalent and would silently fail.

Usage:
    uv run md_to_toml.py path/to/agent.md
    uv run md_to_toml.py path/to/agent.md --output path/to/agent.toml
"""

import argparse
import sys
from pathlib import Path

import frontmatter
import tomli_w

CODEX_OPTIONAL_KEYS = (
    "nickname_candidates",
    "model_reasoning_effort",
    "sandbox_mode",
    "mcp_servers",
    "skills",
)


def transpile(md_path: Path, toml_path: Path) -> None:
    """Read ``md_path`` and write a Codex-compatible ``toml_path``."""
    post = frontmatter.load(md_path)
    meta = post.metadata
    body = post.content.strip()

    name = meta.get("name") or md_path.stem
    description = meta.get("description")
    if not description:
        raise ValueError(f"{md_path} is missing required 'description' frontmatter")
    if not body:
        raise ValueError(f"{md_path} has an empty body; Codex needs developer_instructions")

    out: dict[str, object] = {
        "name": str(name),
        "description": str(description).strip(),
        "developer_instructions": body,
    }

    if "model" in meta:
        out["model"] = str(meta["model"])

    codex_extras = meta.get("codex") or {}
    if not isinstance(codex_extras, dict):
        raise TypeError(
            f"{md_path}: top-level 'codex:' frontmatter must be a mapping, got {type(codex_extras).__name__}"
        )
    for key in CODEX_OPTIONAL_KEYS:
        if key in codex_extras:
            out[key] = codex_extras[key]

    toml_path.write_bytes(tomli_w.dumps(out).encode())


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
