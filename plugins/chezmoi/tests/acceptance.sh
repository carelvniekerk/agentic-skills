#!/usr/bin/env bash
# Acceptance tests for chezmoi-guard.sh.
# Feeds the hook real PreToolUse events on stdin and checks each decision.
# Requires an initialised chezmoi with at least one managed file.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly HOOK="$HERE/../hooks/chezmoi-guard.sh"

pass=0
fail=0

# Print the hook's decision as "allow", "deny:<reason>", or "error:<rc>".
run_hook() {
  local out rc
  out=$(printf '%s' "$1" | "$HOOK" 2>/dev/null)
  rc=$?
  ((rc != 0)) && {
    printf 'error:%s' "$rc"
    return
  }
  [[ -z "$out" ]] && {
    printf 'allow'
    return
  }
  printf '%s:%s' \
    "$(jq -r '.hookSpecificOutput.permissionDecision // "malformed"' <<<"$out")" \
    "$(jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$out")"
}

# check <label> <allow|deny> <actual> [substring the reason must contain]
check() {
  local label="$1" expect="$2" actual="$3" needle="${4:-}"
  local verdict=${actual%%:*} reason=${actual#*:}
  [[ "$actual" == "$verdict" ]] && reason=""

  if [[ "$verdict" != "$expect" ]]; then
    printf 'FAIL  %-52s expected %s, got %s\n' "$label" "$expect" "$verdict"
    ((fail++))
  elif [[ -n "$needle" && "$reason" != *"$needle"* ]]; then
    printf 'FAIL  %-52s reason lacks %q\n' "$label" "$needle"
    printf '        reason: %s\n' "$reason"
    ((fail++))
  else
    printf 'ok    %-52s %s\n' "$label" "$verdict"
    ((pass++))
  fi
}

event() {
  jq -nc --arg f "$1" --arg c "${2:-$HOME}" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$c,
      tool_input:{file_path:$f, content:"x"}}'
}

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi is not installed; nothing to test." >&2
  exit 0
fi

MANAGED=$(chezmoi managed --path-style absolute --include=files 2>/dev/null | head -1)
if [[ -z "$MANAGED" ]]; then
  echo "chezmoi manages no files; nothing to test." >&2
  exit 0
fi
SOURCE_DIR=$(chezmoi source-path)
SOURCE_FILE=$(chezmoi source-path -- "$MANAGED" 2>/dev/null || printf '%s/.chezmoiignore' "$SOURCE_DIR")
REL=${MANAGED#"$HOME"/}

printf 'managed sample: %s\n' "$MANAGED"
printf 'source dir:     %s\n\n' "$SOURCE_DIR"

check "absolute path to a managed file" deny \
  "$(run_hook "$(event "$MANAGED")")" "$SOURCE_DIR"

check "same path relative to \$HOME" deny \
  "$(run_hook "$(event "$REL" "$HOME")")" "$SOURCE_DIR"

check "same path with a leading ~" deny \
  "$(run_hook "$(event "~/$REL")")" "$SOURCE_DIR"

check "path under the chezmoi source directory" allow \
  "$(run_hook "$(event "$SOURCE_FILE")")"

check "/tmp/scratch.txt" allow \
  "$(run_hook "$(event /tmp/scratch.txt)")"

# A stale cache must not survive chezmoi disappearing, hence the pruned PATH.
out=$(printf '%s' "$(event "$MANAGED")" | env PATH=/usr/bin:/bin bash "$HOOK" 2>/dev/null)
rc=$?
if [[ -z "$out" && $rc -eq 0 ]]; then
  printf 'ok    %-52s allow (no stdout, exit 0)\n' "chezmoi removed from PATH"
  ((pass++))
else
  printf 'FAIL  %-52s expected empty stdout and exit 0, got %q / %s\n' \
    "chezmoi removed from PATH" "$out" "$rc"
  ((fail++))
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
