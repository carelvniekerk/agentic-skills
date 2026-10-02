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
POETRY=$(mktemp -d "${TMPDIR:-/tmp}/uv-redirect-poetry.XXXXXX")
trap 'rm -rf "$PROJECT" "$BARE" "$POETRY"' EXIT
printf '[project]\nname = "acceptance"\n' >"$PROJECT/pyproject.toml"
printf '[tool.poetry]\nname = "acceptance"\n' >"$POETRY/pyproject.toml"
: >"$POETRY/poetry.lock"

deny_cases=(
  'pip install requests'
  'pip3 install -r requirements.txt'
  'python -m pip install torch'
  'sudo pip install foo'
  'cd /tmp && pip install foo'
  'pip uninstall numpy'
  'ruff check . && python3 -m pip install black'
  '/usr/bin/pip install x'
  '.venv/bin/pip install x'
  '.venv/bin/python -m pip install x'
  'python3.12 -m pip install x'
  'python -I -X dev -m pip install x'
  'pip3.12 install x'
  'PIP_INDEX_URL=https://example.org pip install y'
  'env PIP_NO_CACHE_DIR=1 pip install x'
  'command pip install x'
  'time pip install x'
  'nice -n 10 pip install x'
  'sudo -H pip install x'
  'sudo -u root pip install x'
  'xargs -n 1 pip install < reqs.txt'
  'pip -q install x'
  'pip --disable-pip-version-check install x'
  'pip --proxy http://proxy:3128 install x'
  'python -mpip install x'
  'echo `pip install x`'
  'echo $(pip install x)'
  '{ pip install x; }'
  'if true; then pip install x; fi'
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
  'uv run python -m pip list'
  'pip download x'
  'pip --proxy http://proxy:3128 list'
  'python script.py -m pip install x'
  'python -c "import pip" install'
  'sudo -u pip ls'
  'env PIPX_HOME=/tmp pipx install ruff'
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

check "pip install in a Poetry project names its lockfile" deny \
  "$(run_hook "$(event 'pip install requests' "$POETRY")")" 'poetry.lock'

printf '\n--- failure modes are visible, not silent ---\n\n'

rc=0
printf 'not json' | "$HOOK" >/dev/null 2>&1 || rc=$?
check "malformed input exits non-zero" error "$( ((rc == 1)) && echo error || echo "allow:rc=$rc")"

rc=0
printf '%s' "$(event 'pip install x' "$PROJECT")" | PATH=/nonexistent /bin/bash "$HOOK" >/dev/null 2>&1 || rc=$?
check "missing jq exits non-zero" error "$( ((rc == 1)) && echo error || echo "allow:rc=$rc")"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
