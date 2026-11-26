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
for needle in "$p/dream-staging" "$p/dream-state" "dreaming:dreamer" "dreaming:dream skill (argument: apply)" "Global instructions file: $HOME/.claude/CLAUDE.md"; do
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

project 3 10 0 10
p=$PROJ
check "cwd outside a git repository gives Project root: none" fires \
  "$(run_gate "$(gate_event "$p")")" "Project root: none"

project 3 10 0 10
p=$PROJ
if command -v git >/dev/null 2>&1; then
  repo="$ROOT/repo$n"
  mkdir -p "$repo/sub/dir"
  git -C "$repo" init -q
  expected=$(git -C "$repo" rev-parse --show-toplevel)
  check "cwd in a repository subdirectory gives the repository root" fires \
    "$(run_gate "$(gate_event "$p" "$repo/sub/dir")")" "Project root: $expected"
fi

project 3 10 0 10
p=$PROJ
check "cwd that does not exist still fires" fires \
  "$(run_gate "$(gate_event "$p" "$ROOT/missing")")" "Project root: none"

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

check "dreamer stages a project CLAUDE.md under staging" allow \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/project/CLAUDE.md")")"
check "dreamer stages a rules file under staging" allow \
  "$(run_guard "$(guard_event $AGENT "$g/dream-staging/project/.claude/rules/python.md")")"
check "dreamer writes the project CLAUDE.md directly" deny \
  "$(run_guard "$(guard_event $AGENT "$ROOT/repo/CLAUDE.md")")" "dream-staging"
check "dreamer writes a project rules file directly" deny \
  "$(run_guard "$(guard_event $AGENT "$ROOT/repo/.claude/rules/python.md")")" "dream-staging"
check "main session writes the project CLAUDE.md" allow \
  "$(run_guard "$(guard_event "" "$ROOT/repo/CLAUDE.md")")"

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

echo
echo "learning-nudge.sh"

readonly NUDGE="$HERE/../hooks/learning-nudge.sh"
readonly REJECT_TEXT="The user doesn't want to proceed with this tool use. The tool use was rejected (eg. if it was a file edit, the new_string was NOT written to the file). STOP what you are doing and wait for the user to tell you how to proceed."
readonly HARNESS_NOTE="Note: The user's next message may contain a correction or preference. Pay close attention, and if they explain what went wrong, consider saving that to memory for future sessions."

# Transcript entries in the shape Claude Code writes them.
t_typed() { jq -nc --arg c "$1" '{type:"user", origin:{kind:"human"}, message:{role:"user", content:$c}}'; }
t_tool_use() { jq -nc --arg i "$1" --arg n "$2" '{type:"assistant", message:{role:"assistant", content:[{type:"tool_use", id:$i, name:$n, input:{}}]}}'; }
t_result() {
  jq -nc --arg i "$1" --arg t "$2" --argjson e "$3" \
    '{type:"user", message:{role:"user", content:[{type:"tool_result", tool_use_id:$i, is_error:$e, content:$t}]}}'
}
t_interrupt() { jq -nc '{type:"user", message:{role:"user", content:[{type:"text", text:"[Request interrupted by user for tool use]"}]}}'; }

# transcript <line>...: writes a fixture transcript and sets TRANSCRIPT.
transcript() {
  n=$((n + 1))
  TRANSCRIPT="$ROOT/t$n.jsonl"
  printf '%s\n' "$@" >"$TRANSCRIPT"
}

nudge_event() {
  jq -nc --arg t "${2:-$TRANSCRIPT}" --arg p "$1" --arg c "${3:-$ROOT}" \
    '{hook_event_name:"UserPromptSubmit", transcript_path:$t, cwd:$c, prompt:$p}'
}

# Print "silent", "fires:<additionalContext>", or "error:<detail>".
run_nudge() {
  local out rc
  out=$(printf '%s' "$1" | "$NUDGE" 2>/dev/null)
  rc=$?
  ((rc != 0)) && {
    printf 'error:exit %s' "$rc"
    return
  }
  [[ -z "$out" ]] && {
    printf 'silent'
    return
  }
  if [[ $(jq -r '.hookSpecificOutput.hookEventName // "malformed"' <<<"$out" 2>/dev/null) != UserPromptSubmit ]]; then
    printf 'error:malformed JSON'
    return
  fi
  printf 'fires:%s' "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")"
}

transcript "$(t_typed "tidy the hooks")" "$(t_tool_use tu1 Bash)" "$(t_result tu1 "$REJECT_TEXT" true)"
check "rejected Bash call in the last turn" fires \
  "$(run_nudge "$(nudge_event "why did you do that")")" "rejected 1 tool call (Bash)"

transcript "$(t_typed "tidy the hooks")" "$(t_tool_use tu1 Edit)" \
  "$(t_result tu1 "$REJECT_TEXT"$'\n\n'"use uv run instead of python"$'\n\n'"$HARNESS_NOTE" true)"
ctx=$(run_nudge "$(nudge_event "ok")")
check "rejection text from the user is passed on" fires "$ctx" "use uv run instead of python"
check "harness note is not passed on as user text" fires "$ctx" "rejection of Edit"
[[ "$ctx" == *"Pay close attention"* ]] && {
  printf 'FAIL  %-58s harness note leaked\n' "harness note stripped"
  ((fail++))
} || {
  printf 'ok    %-58s %s\n' "harness note stripped" "absent"
  ((pass++))
}

transcript "$(t_typed "tidy the hooks")" "$(t_tool_use tu1 Bash)" "$(t_interrupt)"
check "interrupted request in the last turn" fires \
  "$(run_nudge "$(nudge_event "go on")")" "interrupted 1 request"

transcript "$(t_typed "first")" "$(t_tool_use tu1 Bash)" "$(t_result tu1 "$REJECT_TEXT" true)" \
  "$(t_typed "second")" "$(t_tool_use tu2 Read)" "$(t_result tu2 "file text" false)"
check "rejection before the previous prompt is old news" silent \
  "$(run_nudge "$(nudge_event "carry on")")"

transcript "$(t_typed "first")" "$(t_tool_use tu1 Write)" "$(t_result tu1 "$REJECT_TEXT" true)" \
  "$(t_typed "carry on")"
check "current prompt already written to the transcript" fires \
  "$(run_nudge "$(nudge_event "carry on")")" "(Write)"

transcript "$(t_typed "grep old sessions")" "$(t_tool_use tu1 Bash)" \
  "$(t_result tu1 "  34 $REJECT_TEXT" false)" "$(t_tool_use tu2 Bash)" "$(t_result tu2 "$REJECT_TEXT" false)"
check "rejection wording inside ordinary tool output" silent \
  "$(run_nudge "$(nudge_event "carry on")")"

transcript "$(t_typed "write the file")" "$(t_tool_use tu1 Write)" \
  "$(t_result tu1 "PreToolUse:Write hook denied this tool: the path is outside dream-staging." true)"
check "denial by a guard hook" silent "$(run_nudge "$(nudge_event "carry on")")"

transcript "$(t_typed "read it")" "$(t_tool_use tu1 Read)" "$(t_result tu1 "file text" false)"
check "plain turn, plain prompt" silent "$(run_nudge "$(nudge_event "now run the tests")")"
check "preference wording" fires \
  "$(run_nudge "$(nudge_event "From now on run ruff before the tests")")" "preference"
check "praise wording" fires "$(run_nudge "$(nudge_event "Perfect, keep doing that")")" "praise"
check "never inside another word" silent "$(run_nudge "$(nudge_event "nevertheless, run the tests")")"
check "slash command with preference wording" silent \
  "$(run_nudge "$(nudge_event "/dreaming:dream always")")"
check "context names the working directory" fires \
  "$(run_nudge "$(nudge_event "I prefer tabs" "$TRANSCRIPT" "$ROOT/repo")")" "$ROOT/repo"

transcript "$(t_tool_use tu1 Bash)" "$(t_result tu1 "$REJECT_TEXT" true)"
check "no typed prompt in the tail, whole tail is the turn" fires \
  "$(run_nudge "$(nudge_event "hm")")" "rejected 1"

check "missing transcript, plain prompt" silent \
  "$(run_nudge "$(nudge_event "run it" "$ROOT/none.jsonl")")"
check "missing transcript, preference prompt" fires \
  "$(run_nudge "$(nudge_event "never push" "$ROOT/none.jsonl")")" "preference"
check "garbage on stdin" silent "$(run_nudge 'not json')"

transcript "$(t_typed "x")" "$(t_tool_use tu1 Bash)" "$(t_result tu1 "$REJECT_TEXT" true)"
ctx=$(run_nudge "$(nudge_event "y")")
if [[ "$ctx" == *"want to proceed"* || "$ctx" == *"Request interrupted"* ]]; then
  printf 'FAIL  %-58s context repeats a marker string\n' "context cannot match itself next turn"
  ((fail++))
else
  printf 'ok    %-58s %s\n' "context cannot match itself next turn" "clean"
  ((pass++))
fi

mkdir -p "$ROOT/off/.claude"
echo '{"autoMemoryEnabled": false}' >"$ROOT/off/.claude/settings.json"
check "autoMemoryEnabled false in project settings" silent \
  "$(run_nudge "$(nudge_event "never push" "$TRANSCRIPT" "$ROOT/off")")"
check "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" silent \
  "$(CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 run_nudge "$(nudge_event "never push")")"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
((fail == 0))
