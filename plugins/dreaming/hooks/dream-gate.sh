#!/usr/bin/env bash
# SessionStart (startup): tell the main session when a memory consolidation
# pass is due, so it starts the dreaming:dreamer subagent in view.
#
# A hook cannot spawn a subagent itself. It can only inject context, so the
# gate decides whether a pass is worth running and the session does the rest.
#
# Fails open throughout and prints nothing unless a pass is due. SessionStart
# cannot block, and a broken gate must not cost the user a session.
set -uo pipefail

readonly MIN_AGE_DAYS=7        # time arm: a pass at most once a week
readonly MIN_TOPIC_FILES=2     # time arm: one fact file leaves nothing to merge
readonly SIZE_LINES=80         # size arm: MEMORY.md is getting long
readonly SIZE_COOLDOWN_DAYS=1  # size arm: no refire at every start
readonly LOCK_MINUTES=240      # parallel sessions must not each start a pass

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null) || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null) || cwd=""

# Transcripts sit directly in ~/.claude/projects/<slug>/ with memory/ beside
# them. The slug comes from the git repo, not from cwd, so cwd cannot rebuild it.
proj=${DREAMING_PROJECT_DIR:-}
[[ -z "$proj" && -n "$transcript" ]] && proj=${transcript%/*}
[[ -n "$proj" && -d "$proj" ]] || exit 0

SETTINGS=()
if [[ -n "$cwd" ]]; then
  SETTINGS+=("$cwd/.claude/settings.local.json" "$cwd/.claude/settings.json")
fi
SETTINGS+=("$HOME/.claude/settings.json")

# First definition wins, most specific file first.
setting() {
  local key="$1" file val
  for file in "${SETTINGS[@]}"; do
    [[ -r "$file" ]] || continue
    val=$(jq -r --arg k "$key" \
      'if type == "object" and has($k) then (.[$k] | tostring) else empty end' \
      "$file" 2>/dev/null) || continue
    if [[ -n "$val" ]]; then
      printf '%s' "$val"
      return
    fi
  done
}

[[ "$(setting autoMemoryEnabled)" == "false" ]] && exit 0
[[ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-}" == "1" ]] && exit 0

# A custom memory directory breaks the layout the agent, the guard and the
# transcript lookup all assume (memory/ beside the transcripts), and one global
# override would put every project in the same directory. Unsupported.
[[ -n "$(setting autoMemoryDirectory)" ]] && exit 0

mem="$proj/memory"
[[ -d "$mem" ]] || exit 0

# State lives beside memory/, never inside it, so Claude Code never loads it
# and the dreamer cannot mistake it for a memory file.
state="$proj/dream-state"
stage="$proj/dream-staging"
lock="$proj/dream-lock"

if [[ -e "$lock" && -n "$(find "$lock" -mmin "-$LOCK_MINUTES" 2>/dev/null)" ]]; then
  exit 0
fi

now=$(date +%s)
last=0
if [[ -f "$state" ]]; then
  IFS= read -r stamp <"$state"
  [[ "$stamp" =~ ^[0-9]+$ ]] && last=$stamp
fi
age_days=$(((now - last) / 86400))

lines=0
[[ -f "$mem/MEMORY.md" ]] && lines=$(($(wc -l <"$mem/MEMORY.md")))

topics=$(($(find "$mem" -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md 2>/dev/null | wc -l)))

# Changed means newer than the state file. With no state file every file counts.
if [[ -f "$state" ]]; then
  changed=$(find "$mem" -type f -name '*.md' -newer "$state" -print -quit 2>/dev/null)
else
  changed=$(find "$mem" -type f -name '*.md' -print -quit 2>/dev/null)
fi

reason=""
if [[ -n "$changed" ]] && ((topics >= MIN_TOPIC_FILES && age_days >= MIN_AGE_DAYS)); then
  if ((last == 0)); then
    reason="memory has not been consolidated yet and holds $topics fact files"
  else
    reason="memory changed since the last pass $age_days days ago"
  fi
elif ((lines > SIZE_LINES && age_days >= SIZE_COOLDOWN_DAYS)); then
  reason="MEMORY.md has $lines lines"
fi
[[ -n "$reason" ]] || exit 0

touch "$lock" 2>/dev/null || exit 0

# The dreamer also reads the project's CLAUDE.md and .claude/rules/, which live
# at the repository root and not at cwd. Without a root the agent skips those
# steps, so a failed lookup degrades the pass and never blocks it.
root=none
if [[ -n "$cwd" ]] && command -v git >/dev/null 2>&1; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=""
  [[ -n "$root" ]] || root=none
fi

context="Native memory for this project is due a consolidation pass ($reason).
The dreaming plugin runs the pass in three stages.
First, this session starts the dreaming:dreamer subagent in the background with the Agent tool, briefed with these paths.
Memory directory: $mem
Staging directory: $stage
State file: $state
Project root: $root
Second, the agent writes a proposal and a report only under the staging directory, and the user's own request does not wait for it.
It may propose changes to the project's CLAUDE.md and .claude/rules/ files as well, including moving a memory that is a team-wide rule into CLAUDE.md.
Third, when the agent reports back, the dreaming:dream skill (argument: apply) shows the diff and asks the user, and nothing is written to the memory directory or to a project file before that approval."

jq -n --arg c "$context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
exit 0
