#!/usr/bin/env bash
# PreToolUse: refuse to let a private key reach disk in the first place.
# Delete the extension check below to apply this to every file type.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")

case "$file" in
  *.py | *.pyi) ;;
  *) exit 0 ;;
esac

# Write -> .content, Edit -> .new_string, NotebookEdit -> .new_source
content=$(jq -r '.tool_input.content // .tool_input.new_string // .tool_input.new_source // empty' <<<"$input")
[[ -n "$content" ]] || exit 0

tmp=$(mktemp "${TMPDIR:-/tmp}/secrets-guard.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '%s' "$content" > "$tmp"

pch detect-private-key "$tmp" >/dev/null 2>&1
rc=$?

# 127 means neither the console script nor uvx is installed. Denying every
# write because the checker is missing would be worse than the risk it covers,
# so say so on stderr and let the write through.
if (( rc == 127 )); then
  echo "secrets-guard: pre-commit-hooks is not reachable (no detect-private-key on PATH, no uvx), so this write was not scanned." >&2
  exit 0
fi

if (( rc != 0 )); then
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
