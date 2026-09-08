#!/usr/bin/env bash
# PreToolUse: refuse a direct pip invocation and point at the uv equivalent.
#
# pip installs into whichever environment happens to be active and leaves
# uv.lock untouched. Only the environment-mutating subcommands are refused;
# pip list, pip show and pip --version are read-only and pass.
#
# jq plus shell builtins only. This fires on every Bash tool call, so nothing
# beyond the single jq is spawned to reach the decision.
set -uo pipefail

# Populated by heredoc_delim.
HEREDOC_DELIM=""

# Extract the delimiter word of a heredoc opened on this line, if any.
# Sets HEREDOC_DELIM to the empty string when the line opens none.
heredoc_delim() {
  local line="$1" rest
  HEREDOC_DELIM=""
  case "$line" in
    *"<<"*) ;;
    *) return ;;
  esac
  rest=${line#*<<}
  rest=${rest#-}                        # the <<- indented variant
  case "$rest" in
    "<"*) return ;;                     # <<< is a here string, not a heredoc
  esac
  rest=${rest#"${rest%%[![:blank:]]*}"} # drop leading blanks
  rest=${rest%%[[:blank:]]*}            # first word only
  # Quoting the delimiter suppresses expansion in the body; the quote
  # characters are not part of the delimiter itself.
  rest=${rest//\'/}
  rest=${rest//\"/}
  rest=${rest//\\/}
  HEREDOC_DELIM=$rest
}

# Populated by strip_heredocs.
STRIPPED=""

# Drop heredoc bodies. Their contents are data written to a file, never
# commands, so anything they mention must not reach the matcher.
strip_heredocs() {
  local text="$1" line trimmed skip_to="" out=""
  while IFS= read -r line; do
    if [[ -n "$skip_to" ]]; then
      trimmed=${line#"${line%%[![:blank:]]*}"}
      [[ "$trimmed" == "$skip_to" ]] && skip_to=""
      continue
    fi
    out+="$line"$'\n'
    heredoc_delim "$line"
    [[ -n "$HEREDOC_DELIM" ]] && skip_to=$HEREDOC_DELIM
  done <<<"$text"
  STRIPPED=$out
}

# Parallel arrays: TOKENS holds the token text, TKIND holds "w" for a word and
# "s" for a command separator.
TOKENS=()
TKIND=()

# Quote-aware split into words and separators. Not a shell parser: it tracks
# quoting and backslash escapes so a separator inside a quoted string does not
# start a new command, which is what keeps `echo "a && pip install b"` out of
# the matcher.
tokenise() {
  local text="$1" n=${#1} i=0 c cur="" have=0 quote=""
  TOKENS=()
  TKIND=()
  while ((i < n)); do
    c=${text:i:1}
    if [[ -n "$quote" ]]; then
      if [[ "$c" == "$quote" ]]; then quote=""; else cur+=$c; fi
      ((i++))
      continue
    fi
    case "$c" in
      "'" | '"')
        quote=$c
        have=1
        ;;
      '\')
        ((i++))
        cur+=${text:i:1}
        have=1
        ;;
      ' ' | $'\t')
        if ((have)); then
          TOKENS+=("$cur")
          TKIND+=(w)
          cur=""
          have=0
        fi
        ;;
      '&' | '|' | ';' | '(' | ')' | $'\n')
        if ((have)); then
          TOKENS+=("$cur")
          TKIND+=(w)
          cur=""
          have=0
        fi
        TOKENS+=("$c")
        TKIND+=(s)
        ;;
      *)
        cur+=$c
        have=1
        ;;
    esac
    ((i++))
  done
  if ((have)); then
    TOKENS+=("$cur")
    TKIND+=(w)
  fi
}

# The offending subcommand, set by scan_tokens on a match.
PIP_SUB=""

# Walk the token stream and look for pip in command position only. A token is
# in command position at the start of the stream, after a separator, or after a
# sudo that was itself in command position. Everything else is an argument,
# which is what keeps `grep -r "pip install" docs/` out of the matcher.
scan_tokens() {
  local n=${#TOKENS[@]} i j cmdpos=1 tok
  PIP_SUB=""
  for ((i = 0; i < n; i++)); do
    if [[ ${TKIND[i]} == s ]]; then
      cmdpos=1
      continue
    fi
    ((cmdpos)) || continue
    tok=${TOKENS[i]}
    case "$tok" in
      sudo)
        continue # the next word is still the command
        ;;
      pip | pip3)
        cmdpos=0
        if [[ ${TKIND[i + 1]:-s} == w ]]; then
          case "${TOKENS[i + 1]}" in
            install | uninstall)
              PIP_SUB=${TOKENS[i + 1]}
              return 0
              ;;
          esac
        fi
        ;;
      python | python3)
        cmdpos=0
        # Scan the rest of this command for `-m pip <subcommand>`, so
        # interpreter flags before -m do not hide the invocation.
        for ((j = i + 1; j < n; j++)); do
          [[ ${TKIND[j]} == w ]] || break
          [[ ${TOKENS[j]} == "-m" ]] || continue
          [[ ${TKIND[j + 1]:-s} == w && ${TOKENS[j + 1]} == "pip" ]] || break
          if [[ ${TKIND[j + 2]:-s} == w ]]; then
            case "${TOKENS[j + 2]}" in
              install | uninstall)
                PIP_SUB=${TOKENS[j + 2]}
                return 0
                ;;
            esac
          fi
          break
        done
        ;;
      *)
        cmdpos=0
        ;;
    esac
  done
  return 1
}

# A uv project is one with a pyproject.toml or uv.lock at or above cwd.
# Builtin tests only, so this costs no process.
in_uv_project() {
  local dir="$1"
  [[ -n "$dir" ]] || return 1
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    [[ -f "$dir/pyproject.toml" || -f "$dir/uv.lock" ]] && return 0
    dir=${dir%/*}
  done
  [[ -f /pyproject.toml || -f /uv.lock ]]
}

# One jq invocation for both fields: cwd on the first line, the command from
# the second line onwards so its own newlines survive intact.
payload=$(jq -r '(.cwd // ""), (.tool_input.command // "")')
if [[ "$payload" == *$'\n'* ]]; then
  cwd=${payload%%$'\n'*}
  cmd=${payload#*$'\n'}
else
  cwd=$payload
  cmd=""
fi
[[ -n "$cmd" ]] || exit 0

strip_heredocs "$cmd"
tokenise "$STRIPPED"
scan_tokens || exit 0

if in_uv_project "$cwd"; then
  if [[ "$PIP_SUB" == install ]]; then
    reason="pip installs into whichever environment happens to be active and leaves uv.lock untouched, so this uv project would fall out of sync. Add the dependency with \`uv add <package>\` instead, which updates pyproject.toml and the lockfile together. If the package genuinely must stay out of the manifest, \`uv pip install\` is the deliberate escape hatch."
  else
    reason="pip uninstalls from whichever environment happens to be active and leaves uv.lock untouched, so this uv project would fall out of sync. Drop the dependency with \`uv remove <package>\` instead, which updates pyproject.toml and the lockfile together. If the package was never in the manifest, \`uv pip uninstall\` is the deliberate escape hatch."
  fi
else
  reason="pip acts on whichever interpreter happens to be first on PATH, which is rarely the intended one. Use \`uv pip $PIP_SUB\` instead, which resolves against the active virtual environment explicitly. There is no pyproject.toml or uv.lock at or above $cwd, so \`uv add\` does not apply here."
fi

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
