#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""UserPromptExpansion hook: state how a uv project launches.

Fires for the slash commands /verify, /run and /run-skill-generator and adds
a short list of launch facts read from the project: console scripts, packages
with a __main__.py, PEP 723 scripts, dependency groups, .uvgroups,
.python-version and the names (never the values) set in .envrc. Those skills
then confirm a recipe instead of discovering one by trial.

The text is factual, because imperative text injected mid-conversation can
trip Claude's prompt-injection defences. Nothing is run, so every line is a
declaration in a file and not proof that the launch works.
"""

import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any

# The matcher in hooks.json uses only letters, hyphens and "|", which the hooks
# reference treats as an exact list. This check repeats it so that a later edit
# to the matcher that turns it into an unanchored regex cannot widen the hook.
TARGET_COMMANDS = frozenset({"verify", "run", "run-skill-generator"})

# Below the documented 10,000 character cap on injected context.
MAX_CHARS = 9000
MAX_LINES = 40
MAX_ITEMS = 8
SKIP_DIRS = frozenset({"node_modules", "tests", "test", "venv", "build", "dist"})
ENVRC_DIRECTIVE = re.compile(
    r"^(layout|use|dotenv|dotenv_if_exists|source_env|source_up|watch_file)\b",
)
ENVRC_EXPORT = re.compile(r"^export\s+([A-Za-z_][A-Za-z0-9_]*)=")
PEP723_START = re.compile(r"^# /// script\s*$", re.MULTILINE)


def find_project_root(start: Path) -> Path | None:
    """Find the nearest directory at or above start that holds a pyproject.toml.

    Args:
        start: The directory to begin the search in.

    Returns:
        The directory holding pyproject.toml, or None if there is none.

    """
    for directory in (start, *start.parents):
        if (directory / "pyproject.toml").is_file():
            return directory
    return None


def load_pyproject(root: Path) -> tuple[dict[str, Any], str | None]:
    """Parse the project's pyproject.toml.

    Args:
        root: The project root.

    Returns:
        The parsed table and None, or an empty table and a one-line reason
        when the file cannot be read or parsed.

    """
    try:
        return tomllib.loads((root / "pyproject.toml").read_text("utf-8")), None
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        return {}, f"{type(exc).__name__}: {exc}"


def _limited(items: list[str]) -> list[str]:
    """Cut a list to MAX_ITEMS entries and say how many were left out.

    Args:
        items: The entries to cut.

    Returns:
        The entries, with a closing marker when some were dropped.

    """
    if len(items) <= MAX_ITEMS:
        return items
    return [*items[:MAX_ITEMS], f"... and {len(items) - MAX_ITEMS} more"]


def entry_points(pyproject: dict[str, Any], key: str) -> list[str]:
    """List the entries of [project.scripts] or [project.gui-scripts].

    Args:
        pyproject: The parsed pyproject.toml.
        key: Either "scripts" or "gui-scripts".

    Returns:
        One "name = target" string per entry, sorted by name.

    """
    table = pyproject.get("project", {}).get(key, {})
    if not isinstance(table, dict):
        return []
    return [f"{name} = {target}" for name, target in sorted(table.items())]


def main_packages(root: Path) -> list[str]:
    """Find packages that can run with python -m.

    Args:
        root: The project root. Both root and root/src are searched, one
            level deep.

    Returns:
        The package names that contain a __main__.py, sorted and unique.

    """
    found: set[str] = set()
    for base in (root / "src", root):
        if not base.is_dir():
            continue
        for child in base.iterdir():
            hidden = child.name.startswith(".")
            skipped = hidden or child.name in SKIP_DIRS
            if child.is_dir() and not skipped and (child / "__main__.py").is_file():
                found.add(child.name)
    return sorted(found)


def inline_scripts(root: Path) -> list[str]:
    """Find PEP 723 scripts in the project root and in scripts/.

    Args:
        root: The project root.

    Returns:
        The paths relative to root of files that open a "# /// script" block
        within their first 4096 characters.

    """
    found: list[str] = []
    candidates = [*sorted(root.glob("*.py")), *sorted((root / "scripts").glob("*.py"))]
    for path in candidates:
        try:
            with path.open(encoding="utf-8", errors="replace") as handle:
                head = handle.read(4096)
        except OSError:
            continue
        if PEP723_START.search(head):
            found.append(str(path.relative_to(root)))
    return found


def meaningful_lines(path: Path) -> list[str]:
    """Read the non-blank, non-comment lines of a small text file.

    Args:
        path: The file to read.

    Returns:
        The stripped lines, or an empty list if the file is missing or
        unreadable.

    """
    try:
        text = path.read_text("utf-8")
    except OSError, UnicodeDecodeError:
        return []
    stripped = (line.strip() for line in text.splitlines())
    return [line for line in stripped if line and not line.startswith("#")]


def envrc_facts(root: Path) -> tuple[list[str], list[str]]:
    """Read which variables and directives .envrc sets, without any values.

    Args:
        root: The project root.

    Returns:
        The exported variable names and the direnv directives (first two
        words only). Values are dropped because .envrc often holds secrets.

    """
    names: list[str] = []
    directives: list[str] = []
    for line in meaningful_lines(root / ".envrc"):
        if export := ENVRC_EXPORT.match(line):
            names.append(export.group(1))
        elif ENVRC_DIRECTIVE.match(line):
            directives.append(" ".join(line.split()[:2]))
    return names, directives


def build_lines(root: Path) -> list[str]:
    """Collect the launch facts for the project at root.

    Args:
        root: The project root.

    Returns:
        The lines of the summary, before the line and character caps.

    """
    pyproject, parse_error = load_pyproject(root)
    project = pyproject.get("project", {})
    version_file = meaningful_lines(root / ".python-version")
    header = (
        f"Launch facts for the project in {root}, read from pyproject.toml and "
        "neighbouring files by the uv plugin. Nothing was run, so these are "
        "declarations and not proof that a launch works."
    )
    lines = [header]
    if parse_error:
        lines.append(f"pyproject.toml could not be parsed ({parse_error}).")
    lines.append(
        f"name: {project.get('name', 'not set')}, "
        f"requires-python: {project.get('requires-python', 'not set')}, "
        f".python-version: {version_file[0] if version_file else 'absent'}, "
        f"uv.lock: {'present' if (root / 'uv.lock').is_file() else 'absent'}",
    )

    launchers = 0
    sections = (
        ("console scripts (uv run <name>)", entry_points(pyproject, "scripts")),
        ("gui scripts (uv run <name>)", entry_points(pyproject, "gui-scripts")),
        (
            "packages with __main__.py (uv run python -m <package>)",
            main_packages(root),
        ),
        ("PEP 723 scripts (uv run --script <file>)", inline_scripts(root)),
    )
    for title, items in sections:
        if items:
            launchers += len(items)
            lines.append(f"{title}:")
            lines.extend(f"  {item}" for item in _limited(items))
    if not launchers:
        lines.append(
            "No console script, __main__.py package or PEP 723 script was "
            "found, so the launch has to come from the README or a Makefile.",
        )

    groups = pyproject.get("dependency-groups", {})
    defaults = pyproject.get("tool", {}).get("uv", {}).get("default-groups", [])
    if groups:
        lines.append(f"dependency groups: {', '.join(_limited(sorted(groups)))}")
    if defaults:
        lines.append(f"uv default-groups: {', '.join(map(str, defaults))}")
    uvgroups = meaningful_lines(root / ".uvgroups")
    if uvgroups:
        lines.append(".uvgroups as written:")
        lines.extend(f"  {item}" for item in _limited(uvgroups))
    names, directives = envrc_facts(root)
    if names or directives:
        shown = ", ".join(_limited(names)) or "none"
        lines.append(f".envrc sets (names only): {shown}")
        if directives:
            lines.append(f".envrc directives: {'; '.join(_limited(directives))}")
    return lines


def build_context(root: Path) -> str:
    """Build the summary and hold it inside the line and character caps.

    Args:
        root: The project root.

    Returns:
        The summary text, at most MAX_LINES lines and MAX_CHARS characters.

    """
    lines = build_lines(root)
    if len(lines) > MAX_LINES:
        omitted = len(lines) - (MAX_LINES - 1)
        lines = [*lines[: MAX_LINES - 1], f"... {omitted} more lines omitted"]
    text = "\n".join(lines)
    if len(text) > MAX_CHARS:
        text = text[: MAX_CHARS - 20] + "\n... cut at the cap"
    return text


def main() -> int:
    """Read one UserPromptExpansion event and print the context for it.

    Returns:
        0 when the event was handled, including the cases with nothing to
        add, and 1 when stdin is not a JSON object.

    """
    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"launch-manifest: stdin is not JSON ({exc.msg})", file=sys.stderr)
        return 1
    if not isinstance(event, dict):
        print("launch-manifest: stdin is not a JSON object", file=sys.stderr)
        return 1

    command = str(event.get("command_name", "")).lstrip("/")
    if command not in TARGET_COMMANDS:
        return 0
    root = find_project_root(Path(event.get("cwd") or Path.cwd()))
    if root is None:
        return 0

    payload = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptExpansion",
            "additionalContext": build_context(root),
        },
    }
    print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
