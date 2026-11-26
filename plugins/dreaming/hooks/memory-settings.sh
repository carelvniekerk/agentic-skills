# Sourced by the dreaming hooks, never run on its own.
# Reads the auto-memory settings Claude Code honours, so every hook backs off
# where native memory is switched off or relocated.

# memory_setting <key> <cwd>: the first definition wins, most specific file first.
memory_setting() {
  local key="$1" cwd="${2:-}" file val
  local files=()
  if [[ -n "$cwd" ]]; then
    files+=("$cwd/.claude/settings.local.json" "$cwd/.claude/settings.json")
  fi
  files+=("$HOME/.claude/settings.json")
  for file in "${files[@]}"; do
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

# memory_disabled <cwd>: succeeds when the dreaming hooks must stay silent.
# A custom memory directory breaks the layout the agent, the guard and the
# transcript lookup all assume (memory/ beside the transcripts), and one global
# override would put every project in the same directory. Unsupported.
memory_disabled() {
  local cwd="${1:-}"
  [[ "$(memory_setting autoMemoryEnabled "$cwd")" == "false" ]] && return 0
  [[ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-}" == "1" ]] && return 0
  [[ -n "$(memory_setting autoMemoryDirectory "$cwd")" ]] && return 0
  return 1
}
