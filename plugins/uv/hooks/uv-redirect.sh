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
# the matcher. The cost is that a substitution inside double quotes, as in
# echo "$(pip install b)", is also treated as data.
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
      '&' | '|' | ';' | '(' | ')' | '`' | $'\n')
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

# The offending subcommand, set by pip_sub_at and scan_tokens on a match.
PIP_SUB=""

# pip's global options that take a separate value. Without this list,
# `pip --proxy http://host install x` would read the URL as the subcommand.
is_pip_valued_option() {
  case "$1" in
    --proxy | --log | --log-file | --cache-dir | --python | --retries | \
      --timeout | --exists-action | --trusted-host | --cert | --client-cert | \
      --keyring-provider | --use-feature | --use-deprecated | --src | -r)
      return 0
      ;;
  esac
  return 1
}

# Given the index of the first word after pip, skip pip's global options and
# check whether the subcommand is one that changes an environment.
pip_sub_at() {
  local j=$1 n=${#TOKENS[@]} tok
  for (( ; j < n; j++)); do
    [[ ${TKIND[j]} == w ]] || return 1
    tok=${TOKENS[j]}
    case "$tok" in
      install | uninstall)
        PIP_SUB=$tok
        return 0
        ;;
      -*)
        is_pip_valued_option "$tok" && ((j++))
        ;;
      *)
        return 1
        ;;
    esac
  done
  return 1
}

# Given the index of the first word after a python interpreter, look for
# `-m pip` or `-mpip` among the interpreter options. The first plain word is a
# script path, and everything after it belongs to the script.
python_m_pip_at() {
  local j=$1 n=${#TOKENS[@]} tok
  for (( ; j < n; j++)); do
    [[ ${TKIND[j]} == w ]] || return 1
    tok=${TOKENS[j]}
    case "$tok" in
      -mpip)
        pip_sub_at $((j + 1))
        return
        ;;
      -m)
        [[ ${TKIND[j + 1]:-s} == w && ${TOKENS[j + 1]} == pip ]] || return 1
        pip_sub_at $((j + 2))
        return
        ;;
      -c) return 1 ;; # the rest is a code string, not a module run
      -X | -W) ((j++)) ;;
      -*) ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# Options of the command wrappers below that consume the following word, so
# that word is not mistaken for the wrapped command.
wrapper_option_takes_value() {
  local wrapper="$1" opt="$2"
  case "$wrapper:$opt" in
    sudo:-u | sudo:-g | sudo:-C | sudo:-D | sudo:-h | sudo:-p | sudo:-U | \
      sudo:-r | sudo:-t | sudo:-T | nice:-n | env:-u | env:-C | \
      xargs:-n | xargs:-I | xargs:-L | xargs:-P | xargs:-d | xargs:-E | \
      xargs:-s | xargs:-a)
      return 0
      ;;
  esac
  return 1
}

# Walk the token stream and look for pip in command position only. A token is
# in command position at the start of the stream, after a separator, after a
# leading VAR=value assignment, after a shell keyword, or after a command
# wrapper such as sudo or env and its options. Everything else is an argument,
# which is what keeps `grep -r "pip install" docs/` out of the matcher.
scan_tokens() {
  local n=${#TOKENS[@]} i cmdpos=1 wrapper="" tok base
  PIP_SUB=""
  for ((i = 0; i < n; i++)); do
    if [[ ${TKIND[i]} == s ]]; then
      cmdpos=1
      wrapper=""
      continue
    fi
    ((cmdpos)) || continue
    tok=${TOKENS[i]}
    if [[ -n "$wrapper" && "$tok" == -* ]]; then
      wrapper_option_takes_value "$wrapper" "$tok" && ((i++))
      continue
    fi
    if [[ "$tok" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      continue
    fi
    # Match on the basename so .venv/bin/pip and /usr/bin/python3 count.
    base=${tok##*/}
    case "$base" in
      sudo | env | command | time | nice | nohup | exec | xargs)
        wrapper=$base
        ;;
      '{' | '!' | if | then | else | elif | do | while | until) ;;
      pip | pip[0-9]*)
        pip_sub_at $((i + 1)) && return 0
        cmdpos=0
        ;;
      python | python[0-9]*)
        python_m_pip_at $((i + 1)) && return 0
        cmdpos=0
        ;;
      *)
        cmdpos=0
        ;;
    esac
  done
  return 1
}

# Classify the nearest Python project at or above cwd. Sets PROJECT_KIND to
# "uv", "other" or "none", and PROJECT_LOCK to the foreign lockfile for
# "other". A pyproject.toml beside poetry.lock or pdm.lock belongs to that
# tool, so suggesting uv add there would be wrong. Builtin tests only, so this
# costs no process.
PROJECT_KIND="none"
PROJECT_LOCK=""
classify_project() {
  local dir="$1" lock
  PROJECT_KIND="none"
  PROJECT_LOCK=""
  [[ -n "$dir" ]] || return
  while :; do
    if [[ -f "$dir/uv.lock" ]]; then
      PROJECT_KIND="uv"
      return
    fi
    if [[ -f "$dir/pyproject.toml" ]]; then
      for lock in poetry.lock pdm.lock; do
        if [[ -f "$dir/$lock" ]]; then
          PROJECT_KIND="other"
          PROJECT_LOCK="$dir/$lock"
          return
        fi
      done
      PROJECT_KIND="uv"
      return
    fi
    [[ -z "$dir" || "$dir" == "/" ]] && return
    dir=${dir%/*}
    [[ -n "$dir" ]] || dir="/"
  done
}

# Without jq the hook cannot read the event. Exit 1 is a non-blocking error:
# the call proceeds, but the transcript shows the guard is not running rather
# than letting it pass silently.
if ! command -v jq >/dev/null 2>&1; then
  echo "uv-redirect: jq not found, so the pip guard is disabled" >&2
  exit 1
fi

# One jq invocation for both fields: cwd on the first line, the command from
# the second line onwards so its own newlines survive intact.
if ! payload=$(jq -r '(.cwd // ""), (.tool_input.command // "")'); then
  echo "uv-redirect: could not parse the hook input, so the pip guard was skipped" >&2
  exit 1
fi
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

classify_project "$cwd"
case "$PROJECT_KIND" in
  uv)
    if [[ "$PIP_SUB" == install ]]; then
      reason="pip installs into an environment without touching uv.lock, so this uv project would fall out of sync. Add the dependency with \`uv add <package>\` instead, which updates pyproject.toml and the lockfile together. If the package genuinely must stay out of the manifest, \`uv pip install\` is the deliberate escape hatch."
    else
      reason="pip uninstalls from an environment without touching uv.lock, so this uv project would fall out of sync. Drop the dependency with \`uv remove <package>\` instead, which updates pyproject.toml and the lockfile together. If the package was never in the manifest, \`uv pip uninstall\` is the deliberate escape hatch."
    fi
    ;;
  other)
    reason="pip changes an environment without recording the change in the project. This project is locked by $PROJECT_LOCK, so change its dependencies through the tool that owns that lockfile. For a one-off outside the manifest, use \`uv pip $PIP_SUB\`."
    ;;
  *)
    reason="pip changes an environment without recording the change anywhere, and a bare pip often targets an interpreter other than the intended one. Use \`uv pip $PIP_SUB\` instead, which acts on the active virtual environment and refuses the system interpreter unless given --system. There is no pyproject.toml or uv.lock at or above $cwd, so \`uv add\` does not apply here."
    ;;
esac

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
