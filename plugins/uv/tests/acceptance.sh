#!/usr/bin/env bash
# Acceptance tests for uv-redirect.sh.
# Feeds the hook real PreToolUse events on stdin and checks each decision.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly HOOK="$HERE/../hooks/uv-redirect.sh"

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
  jq -nc --arg cmd "$1" --arg c "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$c,
      tool_input:{command:$cmd}}'
}

PROJECT=$(mktemp -d "${TMPDIR:-/tmp}/uv-redirect-proj.XXXXXX")
BARE=$(mktemp -d "${TMPDIR:-/tmp}/uv-redirect-bare.XXXXXX")
trap 'rm -rf "$PROJECT" "$BARE"' EXIT
printf '[project]\nname = "acceptance"\n' >"$PROJECT/pyproject.toml"

deny_cases=(
  'pip install requests'
  'pip3 install -r requirements.txt'
  'python -m pip install torch'
  'sudo pip install foo'
  'cd /tmp && pip install foo'
  'pip uninstall numpy'
  'ruff check . && python3 -m pip install black'
)

allow_cases=(
  'uv add requests'
  'uv pip install -e .'
  'pip list'
  'pip show numpy'
  'pip --version'
  'pipx install ruff'
  'pipenv sync'
  'pipdeptree'
  'grep -r "pip install" docs/'
  'echo "run pip install foo first"'
)

for c in "${deny_cases[@]}"; do
  check "$c" deny "$(run_hook "$(event "$c" "$PROJECT")")" 'uv '
done

for c in "${allow_cases[@]}"; do
  check "$c" allow "$(run_hook "$(event "$c" "$PROJECT")")"
done

heredoc=$'cat <<\'EOF\' > README.md\nInstall it with pip install foo\nEOF'
check "heredoc body containing pip install" allow \
  "$(run_hook "$(event "$heredoc" "$PROJECT")")"

printf '\n--- the reason follows the uv-project context ---\n\n'

check "pip install inside a uv project names uv add" deny \
  "$(run_hook "$(event 'pip install requests' "$PROJECT")")" 'uv add'

check "pip uninstall inside a uv project names uv remove" deny \
  "$(run_hook "$(event 'pip uninstall numpy' "$PROJECT")")" 'uv remove'

check "pip install outside a project names uv pip install" deny \
  "$(run_hook "$(event 'pip install requests' "$BARE")")" 'uv pip install'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
