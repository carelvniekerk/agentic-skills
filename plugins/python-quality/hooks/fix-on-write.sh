#!/usr/bin/env bash
# PostToolUse: fix Python files silently, report nothing.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

file=$(jq -r '.tool_input.file_path // empty' <<<"$(cat)")
is_python_file "$file" || exit 0

if ! ruff_available; then
  echo "fix-on-write: ruff is not reachable (not on PATH, no uvx), so $file was left as written." >&2
  exit 0
fi

ruff_would_skip "$file" && exit 0

before=$(digest "$file")

# These exit non-zero when they change something, which is not a failure.
pch trailing-whitespace-fixer "$file" >/dev/null 2>&1
pch end-of-file-fixer "$file" >/dev/null 2>&1

# Lint fixes first, then format. The other order leaves ruff's own edits
# unformatted -- removing an unused import can leave stray blank lines behind --
# so the hook would report a second fix on the next write to the same file.
ruff check --fix-only "$file" >/dev/null 2>&1
ruff format "$file" >/dev/null 2>&1

after=$(digest "$file")
[[ "$before" == "$after" ]] && exit 0

jq -n --arg f "$file" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ($f + " was auto-fixed after this write (formatting, trailing whitespace, final newline). The copy on disk differs from what was just written, so re-read it before editing it again.")
  }
}'
