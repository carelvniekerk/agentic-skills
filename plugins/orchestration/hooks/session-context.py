#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""SessionStart hook: state which orchestration subagents and skill exist.

The text is factual, because imperative text injected mid-conversation can
trip Claude's prompt-injection defences. The hook never fails a session start,
so it exits 0 on every path.
"""

import json
import sys

CONTEXT = (
    "The orchestration plugin provides three read-only Haiku subagents: "
    "orchestration:repo-map lists the files, entry points and dependencies "
    "a change touches, "
    "orchestration:call-sites finds every reference to a symbol, "
    "orchestration:api-docs fetches current library documentation. "
    "orchestration:repo-map and orchestration:call-sites query a local "
    "Graphicle code graph of a synced repository "
    "and check it against the source. "
    "The orchestration:delegate skill describes when each one applies."
)


def main() -> int:
    """Print the SessionStart context as JSON.

    Returns:
        Always 0, so a failure here cannot block a session from starting.

    """
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": CONTEXT,
        },
    }
    try:
        print(json.dumps(payload))
    except OSError as exc:
        print(f"session-context: no context ({type(exc).__name__})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
