#!/usr/bin/env bash
# PreToolUse (Write|Edit): confine the dreaming:dreamer subagent to the
# staging directory.
#
# A plugin agent cannot path-scope its Write tool and ignores hooks in its own
# frontmatter, so the restriction has to live here. The hook input carries
# agent_type for tool calls made inside a subagent, which is what lets this
# deny one agent and leave the main session and every other agent alone.
#
# Fails open if jq is missing or the input is unreadable. For the agent that
# means its prompt is the only remaining restriction, and the skill says so.
set -uo pipefail

# The hooks reference scopes plugin agent types ("dreaming:dreamer") while the
# agent reference says the bare name is passed. Accepting both means the guard
# does not depend on which one the harness sends.

command -v jq >/dev/null 2>&1 || exit 0

{
  IFS= read -r agent
  IFS= read -r file
  IFS= read -r cwd
} < <(jq -r '(.agent_type // ""), (.tool_input.file_path // ""), (.cwd // "")' 2>/dev/null)

case "$agent" in
  dreaming:dreamer | dreamer) ;;
  *) exit 0 ;;
esac
[[ -n "$file" ]] || exit 0

# Resolve symlinks in the directory chain and leave the leaf alone, as `cd -P`
# is POSIX where GNU realpath is missing on macOS. A symlink inside staging that
# points at memory/ therefore resolves to memory/ and is refused.
resolve() {
  local path="$1" dir base resolved
  dir=${path%/*}
  base=${path##*/}
  [[ "$dir" == "$path" ]] && dir=.
  [[ -z "$dir" ]] && dir=/
  if resolved=$(cd -P -- "$dir" 2>/dev/null && pwd -P); then
    printf '%s/%s' "${resolved%/}" "$base"
  else
    printf '%s' "$path"
  fi
}

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

case "$file" in
  '~') file="$HOME" ;;
  '~/'*) file="$HOME/${file#'~/'}" ;;
  /*) ;;
  *) [[ -n "$cwd" ]] && file="${cwd%/}/$file" ;;
esac

# A lexical check first, because resolve() cannot follow a directory that does
# not exist yet and would otherwise let dream-staging/../memory/x.md through.
case "/$file/" in
  */../*) deny "$file contains a '..' segment. The dreamer agent may write only below a dream-staging directory, so give the path without '..'." ;;
esac

target=$(resolve "$file")

# Allowed: a path below a dream-staging directory whose parent also holds a
# memory/ directory, which is what a real project directory looks like.
p=$target
while [[ -n "$p" && "$p" != "/" ]]; do
  p=${p%/*}
  [[ -z "$p" ]] && break
  if [[ "${p##*/}" == "dream-staging" && -d "${p%/*}/memory" ]]; then
    exit 0
  fi
done

deny "The dreamer agent may write only below the dream-staging directory, and $target is outside it. Write the proposed file to the staging directory and leave the memory directory to the apply step."
