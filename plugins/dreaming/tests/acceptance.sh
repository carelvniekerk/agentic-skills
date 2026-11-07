#!/usr/bin/env bash
# Acceptance tests for dream-gate.sh and staging-guard.sh.
# Feeds both hooks real hook events on stdin against fixture projects in a
# temporary directory. HOME points at the fixture too, so the user's real
# settings and memory are never read. No model calls are made.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly GATE="$HERE/../hooks/dream-gate.sh"
readonly GUARD="$HERE/../hooks/staging-guard.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed; nothing to test." >&2
  exit 0
fi

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
export HOME="$ROOT/home"
mkdir -p "$HOME/.claude"
unset CLAUDE_CODE_DISABLE_AUTO_MEMORY DREAMING_PROJECT_DIR

pass=0
fail=0
n=0
readonly DAY=86400
NOW=$(date +%s)

set_mtime() {
  local epoch="$1" ts
  shift
  ts=$(date -r "$epoch" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$epoch" +%Y%m%d%H%M.%S)
  touch -t "$ts" "$@"
}

# project <files> <memory-lines> <file-age-days> <state-age-days|none>
# Builds a project directory with a memory/ beside a fake transcript and sets
# PROJ. It cannot print the path, because a command substitution would lose the
# counter and every fixture would share one directory.
project() {
  local files="$1" lines="$2" file_age="$3" state_age="$4" dir i
  n=$((n + 1))
  dir="$ROOT/p$n"
  mkdir -p "$dir/memory"
  : >"$dir/memory/MEMORY.md"
  for ((i = 0; i < lines; i++)); do echo "- line $i" >>"$dir/memory/MEMORY.md"; done
  for ((i = 0; i < files; i++)); do echo "fact $i" >"$dir/memory/fact_$i.md"; done
  set_mtime $((NOW - file_age * DAY)) "$dir"/memory/*.md
  : >"$dir/s.jsonl"
  if [[ "$state_age" != none ]]; then
    printf '%s\n' $((NOW - state_age * DAY)) >"$dir/dream-state"
    set_mtime $((NOW - state_age * DAY)) "$dir/dream-state"
  fi
  PROJ=$dir
}

gate_event() {
  jq -nc --arg t "$1/s.jsonl" --arg c "${2:-$ROOT}" \
    '{hook_event_name:"SessionStart", source:"startup", transcript_path:$t, cwd:$c}'
}

# Print "silent", "fires:<additionalContext>", or "error:<detail>".
run_gate() {
  local out rc
  out=$(printf '%s' "$1" | "$GATE" 2>/dev/null)
  rc=$?
  ((rc != 0)) && {
    printf 'error:exit %s' "$rc"
    return
  }
  [[ -z "$out" ]] && {
    printf 'silent'
    return
  }
  if [[ $(jq -r '.hookSpecificOutput.hookEventName // "malformed"' <<<"$out" 2>/dev/null) != SessionStart ]]; then
    printf 'error:malformed JSON'
    return
  fi
  printf 'fires:%s' "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")"
}

guard_event() {
  jq -nc --arg a "$1" --arg f "$2" --arg c "${3:-$ROOT}" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", agent_type:$a, cwd:$c,
      tool_input:{file_path:$f, content:"x"}}'
}

run_guard() {
  local out rc
  out=$(printf '%s' "$1" | "$GUARD" 2>/dev/null)
  rc=$?
  ((rc != 0)) && {
    printf 'error:exit %s' "$rc"
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

# check <label> <expected verdict> <actual> [substring the detail must contain]
check() {
  local label="$1" expect="$2" actual="$3" needle="${4:-}"
  local verdict=${actual%%:*} detail=${actual#*:}
  [[ "$actual" == "$verdict" ]] && detail=""

  if [[ "$verdict" != "$expect" ]]; then
    printf 'FAIL  %-58s expected %s, got %s\n' "$label" "$expect" "$verdict"
    [[ -n "$detail" ]] && printf '        detail: %s\n' "$detail"
    ((fail++))
  elif [[ -n "$needle" && "$detail" != *"$needle"* ]]; then
    printf 'FAIL  %-58s detail lacks %q\n' "$label" "$needle"
    printf '        detail: %s\n' "$detail"
    ((fail++))
  else
    printf 'ok    %-58s %s\n' "$label" "$verdict"
    ((pass++))
  fi
}

echo "dream-gate.sh"

project 3 10 5 10
p=$PROJ
check "changed since last pass, ten days ago" fires \
  "$(run_gate "$(gate_event "$p")")" "$p/memory"

project 3 10 5 10
p=$PROJ
ctx=$(run_gate "$(gate_event "$p")")
for needle in "$p/dream-staging" "$p/dream-state" "dreaming:dreamer" "dreaming:dream skill (argument: apply)"; do
  check "context names ${needle##*/}" fires "$ctx" "$needle"
done

project 3 10 0 none
p=$PROJ
check "never consolidated, three fact files" fires \
  "$(run_gate "$(gate_event "$p")")" "not been consolidated"

project 3 10 20 10
p=$PROJ
check "nothing changed since the last pass" silent \
  "$(run_gate "$(gate_event "$p")")"

project 3 10 0 2
p=$PROJ
check "changed but only two days ago, short MEMORY.md" silent \
  "$(run_gate "$(gate_event "$p")")"

project 1 10 0 10
p=$PROJ
check "changed, ten days, but one fact file only" silent \
  "$(run_gate "$(gate_event "$p")")"

project 3 90 20 3
p=$PROJ
check "MEMORY.md over 80 lines, unchanged, three days ago" fires \
  "$(run_gate "$(gate_event "$p")")" "90 lines"

project 3 90 20 0
p=$PROJ
check "MEMORY.md over 80 lines but a pass ran today" silent \
  "$(run_gate "$(gate_event "$p")")"

project 3 10 0 10
p=$PROJ
rm -r "$p/memory"
check "memory directory missing" silent \
  "$(run_gate "$(gate_event "$p")")"

project 3 10 0 10
p=$PROJ
echo '{"autoMemoryEnabled": false}' >"$HOME/.claude/settings.json"
check "autoMemoryEnabled false in user settings" silent \
  "$(run_gate "$(gate_event "$p")")"
rm -f "$HOME/.claude/settings.json"

project 3 10 0 10
p=$PROJ
mkdir -p "$p/work/.claude"
echo '{"autoMemoryEnabled": false}' >"$p/work/.claude/settings.json"
check "autoMemoryEnabled false in project settings" silent \
  "$(run_gate "$(gate_event "$p" "$p/work")")"

project 3 10 0 10
p=$PROJ
out=$(printf '%s' "$(gate_event "$p")" | CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 "$GATE" 2>/dev/null)
check "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" silent "$([[ -z "$out" ]] && echo silent || echo fires)"

project 3 10 0 10
p=$PROJ
first=$(run_gate "$(gate_event "$p")")
check "first start fires" fires "$first"
check "second start inside the lock window" silent \
  "$(run_gate "$(gate_event "$p")")"

project 3 10 0 10
p=$PROJ
touch "$p/dream-lock"
set_mtime $((NOW - 5 * 3600)) "$p/dream-lock"
check "lock older than four hours is ignored" fires \
  "$(run_gate "$(gate_event "$p")")"

project 3 10 0 10
p=$PROJ
mv "$p/memory" "$ROOT/elsewhere$n"
echo "{\"autoMemoryDirectory\": \"$ROOT/elsewhere$n\"}" >"$HOME/.claude/settings.json"
check "autoMemoryDirectory is set, which is unsupported" silent \
  "$(run_gate "$(gate_event "$p")")"
rm -f "$HOME/.claude/settings.json"

project 3 10 0 10
p=$PROJ
out=$(printf '%s' '{"hook_event_name":"SessionStart","source":"startup"}' |
  DREAMING_PROJECT_DIR="$p" "$GATE" 2>/dev/null)
check "DREAMING_PROJECT_DIR replaces transcript_path" fires \
  "$([[ -n "$out" ]] && echo "fires:$out" || echo silent)" "$p/memory"

out=$(printf 'not json' | "$GATE" 2>/dev/null)
rc=$?
check "garbage on stdin" silent "$([[ -z "$out" && $rc -eq 0 ]] && echo silent || echo "error:$out/$rc")"

echo
echo "staging-guard.sh"

project 3 10 0 10
g=$PROJ
mkdir -p "$g/dream-staging"
readonly AGENT=dreaming:dreamer

check "dreamer writes into memory/" deny \
  "$(run_guard "$(guard_event $AGENT "$g/memory/fact_0.md")")" "dream-staging"
check "bare agent_type dreamer writes into memory/" deny \
  "$(run_guard "$(guard_event dreamer "$g/memory/fact_0.md")")"
check "bare agent_type dreamer writes into staging" allow \
  "$(run_guard "$(guard_event dreamer "$g/dream-staging/fact_0.md")")"
check "dreamer writes into staging" allow \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/fact_0.md")")"
check "dreamer writes a nested path in staging" allow \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/new/dir/a.md")")"
check "dreamer writes outside the project" deny \
  "$(run_guard "$(guard_event $AGENT /tmp/x.md)")"
check "dreamer uses .. to climb out of staging" deny \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/../memory/x.md")")" ".."
check "dreamer uses a relative path from memory/" deny \
  "$(run_guard "$(guard_event $AGENT fact_0.md "$g/memory")")"
check "dreamer uses a relative path from staging" allow \
  "$(run_guard "$(guard_event $AGENT fact_0.md "$g/dream-staging")")"

ln -s "$g/memory" "$g/dream-staging/link"
check "dreamer writes through a symlink to memory/" deny \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/link/x.md")")"

mkdir -p "$ROOT/loose/dream-staging"
check "dream-staging with no sibling memory/" deny \
  "$(run_guard "$(guard_event $AGENT "$ROOT/loose/dream-staging/x.md")")"

check "another agent writes into memory/" allow \
  "$(run_guard "$(guard_event other:agent "$g/memory/fact_0.md")")"
check "main session writes into memory/" allow \
  "$(run_guard "$(guard_event "" "$g/memory/fact_0.md")")"
check "tool input without a file_path" allow \
  "$(run_guard '{"hook_event_name":"PreToolUse","agent_type":"dreaming:dreamer","tool_input":{}}')"
check "garbage on stdin" allow "$(run_guard 'not json')"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
