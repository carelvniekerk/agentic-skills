#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""PreToolUse hook on Agent: refresh the code graph before a graph agent starts.

It acts only for orchestration:repo-map and orchestration:call-sites, inside a git
repository, when codebase-memory-mcp is on PATH. The MCP server runs with the
read-only analysis profile, which has no index tool, so this hook is the only
place the index is built. It never blocks the Agent call: every failure exits 0
with a one-line note on stderr, and the agents check the index themselves.
"""

import json
import shutil
import subprocess
import sys

GRAPH_AGENTS = {"orchestration:repo-map", "orchestration:call-sites"}
BINARY = "codebase-memory-mcp"
TIMEOUT_S = 100  # below the 120 s hook timeout, so the hook exits cleanly


def note(message: str) -> int:
    """Print a diagnostic to stderr and allow the call.

    Args:
        message: The diagnostic, without the hook-name prefix.

    Returns:
        Always 0, so the Agent call proceeds.

    """
    print(f"graph-index: {message}", file=sys.stderr)
    return 0


def git_root(cwd: str) -> str | None:
    """Return the top level of the git repository containing cwd.

    Args:
        cwd: The session's working directory from the hook input.

    Returns:
        The absolute repository root, or None outside a git repository.

    """
    git = shutil.which("git")
    if git is None:
        return None
    try:
        # List-form arguments with no shell, so cwd cannot inject a command.
        proc = subprocess.run(  # noqa: S603
            [git, "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=5,
            check=True,
        )
    except subprocess.SubprocessError, OSError:
        return None
    return proc.stdout.strip() or None


def target_root(event: object) -> str | None:
    """Decide whether this Agent call needs an index, and for which repository.

    Args:
        event: The parsed hook input.

    Returns:
        The repository root to index, or None when the hook has nothing to do.

    """
    if not isinstance(event, dict):
        note("stdin is not a JSON object")
        return None
    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        return None
    if tool_input.get("subagent_type") not in GRAPH_AGENTS:
        return None
    root = git_root(str(event.get("cwd") or "."))
    if root is None:
        note("not inside a git repository, so nothing was indexed")
    return root


def run_index(binary: str, root: str) -> dict | None:
    """Index the repository and return the parsed response.

    Args:
        binary: Absolute path of codebase-memory-mcp.
        root: The repository root to index.

    Returns:
        The index_repository response, or None when indexing failed.

    """
    try:
        # List-form arguments with no shell, and root comes from git itself.
        proc = subprocess.run(  # noqa: S603
            [
                binary,
                "cli",
                "--quiet",
                "index_repository",
                json.dumps({"repo_path": root}),
            ],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_S,
            check=True,
        )
        result = json.loads(proc.stdout)
    except (subprocess.SubprocessError, OSError, json.JSONDecodeError) as exc:
        note(f"indexing {root} failed ({type(exc).__name__})")
        return None
    if not isinstance(result, dict):
        note("index_repository returned an unexpected shape")
        return None
    return result


def summary(root: str, result: dict) -> str:
    """Describe the index as facts for Claude's context.

    Args:
        root: The repository root that was indexed.
        result: The parsed index_repository response.

    Returns:
        One factual paragraph naming the project and every gap count.

    """
    project = result.get("project", "unknown")
    status = result.get("status", "unknown")
    return (
        f"The codebase-memory index for {root} was refreshed before this agent call. "
        f"Project {project}, status {status}, "
        f"{result.get('nodes', '?')} nodes and {result.get('edges', '?')} edges. "
        f"Files not indexed: {result.get('not_indexed_files_count', '?')}, "
        f"skipped: {result.get('skipped_count', '?')}, "
        f"parsed partially: {result.get('parse_partial_count', '?')}, "
        f"unusable: {result.get('parse_unusable_count', '?')}. "
        "The index has missed files before without reporting them, "
        "so these counts are a lower bound on the gaps."
    )


def main() -> int:
    """Refresh the index for graph agents and report its gaps.

    Returns:
        Always 0, so a failure here cannot block the Agent call.

    """
    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError:
        return note("stdin is not JSON")
    root = target_root(event)
    if root is None:
        return 0
    binary = shutil.which(BINARY)
    if binary is None:
        return note(f"{BINARY} is not on PATH, so the index was not refreshed")
    result = run_index(binary, root)
    if result is not None:
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": summary(root, result),
            },
        }
        print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
