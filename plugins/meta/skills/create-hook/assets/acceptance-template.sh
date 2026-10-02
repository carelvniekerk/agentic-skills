#!/usr/bin/env bash
# Acceptance tests for a PreToolUse Bash command hook.
# Copy to <plugin>/tests/acceptance.sh, point HOOK at the handler, and fill in
# the two case arrays. Each case feeds the hook a real PreToolUse event on stdin
# and checks the decision, so a hook that silently allows fails here first.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly HOOK="${HOOK:-$HERE/../hooks/CHANGE-ME.sh}"

# Commands the hook must block. Include the forms Claude really produces:
# leading VAR=value, chained &&, absolute binary paths, refspecs, quoting.
deny_cases=(
  "CHANGE-ME dangerous command"
)

# Commands the hook must leave alone, especially near misses that share words
# with the deny cases.
allow_cases=(
  "CHANGE-ME harmless command"
)

pass=0
fail=0

event() {
  jq -nc --arg cmd "$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: "/tmp",
      tool_input: {command: $cmd}}'
}

# Print the decision as allow, deny or error:<code>. Exit 2 and a JSON
# permissionDecision of "deny" both count as deny.
decide() {
  local out rc
  out=$(event "$1" | "$HOOK" 2>/dev/null)
  rc=$?
  if ((rc == 2)); then
    echo deny
  elif [[ "$out" == \{*\} ]]; then
    # Valid JSON decides the outcome on any exit code other than 2.
    jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"$out" 2>/dev/null || echo "error:bad-json"
  elif ((rc != 0)); then
    echo "error:$rc"
  else
    echo allow
  fi
}

check() {
  local expect="$1" cmd="$2" got
  got=$(decide "$cmd")
  if [[ "$got" == "$expect" ]]; then
    printf 'ok    %-6s %s\n' "$got" "$cmd"
    ((pass++))
  else
    printf 'FAIL  expected %s, got %s: %s\n' "$expect" "$got" "$cmd"
    ((fail++))
  fi
}

[[ -x "$HOOK" ]] || { echo "Hook not found or not executable: $HOOK" >&2; exit 1; }

for c in "${deny_cases[@]}"; do check deny "$c"; done
for c in "${allow_cases[@]}"; do check allow "$c"; done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
