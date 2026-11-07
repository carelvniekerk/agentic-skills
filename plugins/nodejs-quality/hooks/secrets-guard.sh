#!/usr/bin/env bash
# PreToolUse: refuse to let a private key reach disk in a JavaScript or TypeScript file.
# Scoped to these extensions so it does not run a second time beside python-quality,
# which guards .py and .pyi. Needs only grep and jq, with no package to install.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")

case "$file" in
  *.ts | *.tsx | *.mts | *.cts | *.js | *.jsx | *.mjs | *.cjs) ;;
  *) exit 0 ;;
esac

# Write -> .content, Edit -> .new_string, NotebookEdit -> .new_source
content=$(jq -r '.tool_input.content // .tool_input.new_string // .tool_input.new_source // empty' <<<"$input")
[[ -n "$content" ]] || exit 0

if grep -q -E -e "$PRIVATE_KEY_PATTERN" <<<"$content"; then
  reason="This write to $file contains what looks like a private key, so it was blocked before reaching disk. Reference key material from an environment variable or a secrets store instead."
  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
fi
exit 0
