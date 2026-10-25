#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""PreToolUse hook: lock the acceptance tests while an implement loop runs.

The implement skill writes `.implement/loop.json` at the start of a loop. The
marker lists the paths of the acceptance tests as globs relative to the
project directory. While a valid marker exists, this hook denies Edit, Write
and NotebookEdit on those paths and on the marker itself. The skill removes
the marker when the loop ends.

Limits, stated so the hook is not mistaken for more than it is:

* It guards the Edit, Write and NotebookEdit tools only. Deleting the marker
  or rewriting a test through Bash is not blocked, so it stops habitual test
  weakening and cannot stop deliberate circumvention.
* It cannot see special-casing inside the implementation, which is the test
  reviewer's job.

The hook fails open. A missing, unreadable, malformed or stale marker allows
the edit, because a broken marker must never block ordinary work. Each failure
other than a missing marker is reported on stderr, so a guard that has
switched itself off is visible in the debug log.
"""

import json
import os
import sys
import time
from pathlib import Path, PurePath

MARKER = Path(".implement") / "loop.json"
MARKER_VERSION = 1
# A marker left behind by a crashed loop must not lock the tests for good.
MAX_AGE_SECONDS = 12 * 60 * 60

REASON = (
    "The acceptance tests are locked while the implement loop runs, so "
    "{target} cannot be edited. If the test is wrong, stop the loop and ask "
    "the user, who can edit it after removing .implement/loop.json."
)


def find_marker(cwd: Path) -> Path | None:
    """Find the loop marker by walking up from the working directory.

    The walk stops at the first directory that holds a `.git` entry, so a
    marker above the repository root cannot affect it.

    Args:
        cwd: The working directory from the hook input.

    Returns:
        The path of the marker file, or None when there is none.

    """
    for directory in (cwd, *cwd.parents):
        candidate = directory / MARKER
        if candidate.is_file():
            return candidate
        if (directory / ".git").exists():
            return None
    return None


def load_globs(marker: Path) -> list[str] | None:
    """Read the protected globs from a marker.

    Args:
        marker: The marker file.

    Returns:
        The globs, or None when the marker is stale or does not match the
        schema. The reason is written to stderr.

    Raises:
        OSError: If the marker cannot be read.
        ValueError: If the marker is not valid JSON.

    """
    age = time.time() - marker.stat().st_mtime
    if age > MAX_AGE_SECONDS:
        print(
            f"test-lock: marker older than {MAX_AGE_SECONDS} s, ignored",
            file=sys.stderr,
        )
        return None
    data = json.loads(marker.read_text(encoding="utf-8"))
    protected = data.get("protected") if isinstance(data, dict) else None
    valid = (
        isinstance(data, dict)
        and data.get("version") == MARKER_VERSION
        and isinstance(protected, list)
        and protected
        and all(isinstance(item, str) and item for item in protected)
    )
    if not valid:
        print("test-lock: marker does not match the schema, ignored", file=sys.stderr)
        return None
    return [f"{item}**" if item.endswith("/") else item for item in protected]


def is_locked(relative: PurePath, globs: list[str]) -> bool:
    """Tell whether a project-relative path is protected.

    Args:
        relative: The path relative to the project directory.
        globs: The protected globs from the marker.

    Returns:
        True for the marker itself and for any path matching a glob.

    """
    if relative == MARKER:
        return True
    return any(relative.full_match(pattern) for pattern in globs)


def target_path(payload: dict, cwd: Path) -> Path | None:
    """Resolve the file an Edit, Write or NotebookEdit call touches.

    Args:
        payload: The hook input.
        cwd: The working directory from the hook input.

    Returns:
        The absolute path with symlinks in existing parents resolved, or None
        when the call names no file.

    """
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return None
    raw = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(raw, str) or not raw:
        return None
    path = Path(raw)
    return Path(os.path.realpath(path if path.is_absolute() else cwd / path))


def decide(payload: dict) -> dict | None:
    """Decide whether the call must be denied.

    Args:
        payload: The hook input.

    Returns:
        The hook output to print, or None to allow the call.

    Raises:
        OSError: If the marker cannot be read.
        ValueError: If the marker is not valid JSON.

    """
    cwd_raw = payload.get("cwd")
    if not isinstance(cwd_raw, str) or not cwd_raw:
        return None
    cwd = Path(os.path.realpath(cwd_raw))
    marker = find_marker(cwd)
    if marker is None:
        return None
    globs = load_globs(marker)
    target = target_path(payload, cwd)
    if globs is None or target is None:
        return None
    project = Path(os.path.realpath(marker.parent.parent))
    if not target.is_relative_to(project):
        return None
    relative = target.relative_to(project)
    if not is_locked(relative, globs):
        return None
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REASON.format(target=relative.as_posix()),
        },
    }


def main() -> int:
    """Read the hook input from stdin and print a denial when one applies.

    Returns:
        Always 0. The hook denies through JSON and never through its exit
        code, and it must not fail a tool call by crashing.

    """
    try:
        payload = json.load(sys.stdin)
        output = decide(payload) if isinstance(payload, dict) else None
    except (OSError, ValueError) as exc:
        print(
            f"test-lock: guard off for this call ({type(exc).__name__}: {exc})",
            file=sys.stderr,
        )
        return 0
    if output is not None:
        print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
