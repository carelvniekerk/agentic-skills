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

printf '\n--- launch-manifest.py on UserPromptExpansion events ---\n\n'

readonly MANIFEST="$HERE/../hooks/launch-manifest.py"
readonly HOOKS_JSON="$HERE/../hooks/hooks.json"

manifest_event() {
  jq -nc --arg n "$1" --arg c "$2" \
    '{hook_event_name:"UserPromptExpansion", expansion_type:"slash_command",
      command_name:$n, command_args:"", prompt:("/" + $n), cwd:$c}'
}

# The additionalContext the hook prints for an event, empty when it prints none.
manifest_context() {
  printf '%s' "$1" | "$MANIFEST" 2>/dev/null |
    jq -r '.hookSpecificOutput.additionalContext // empty'
}

# expect_has <label> <text> <needle>
expect_has() {
  if [[ "$2" == *"$3"* ]]; then
    printf 'ok    %-52s\n' "$1"
    ((pass++))
  else
    printf 'FAIL  %-52s lacks %q\n' "$1" "$3"
    ((fail++))
  fi
}

# expect_lacks <label> <text> <needle>
expect_lacks() {
  if [[ "$2" != *"$3"* ]]; then
    printf 'ok    %-52s\n' "$1"
    ((pass++))
  else
    printf 'FAIL  %-52s contains %q\n' "$1" "$3"
    ((fail++))
  fi
}

LAUNCH=$(mktemp -d "${TMPDIR:-/tmp}/launch-manifest.XXXXXX")
LAUNCH_BARE=$(mktemp -d "${TMPDIR:-/tmp}/launch-manifest-bare.XXXXXX")
LAUNCH_BROKEN=$(mktemp -d "${TMPDIR:-/tmp}/launch-manifest-broken.XXXXXX")
LAUNCH_BIG=$(mktemp -d "${TMPDIR:-/tmp}/launch-manifest-big.XXXXXX")
trap 'rm -rf "$PROJECT" "$BARE" "$POETRY" "$LAUNCH" "$LAUNCH_BARE" "$LAUNCH_BROKEN" "$LAUNCH_BIG"' EXIT

mkdir -p "$LAUNCH/src/mypkg" "$LAUNCH/scripts" "$LAUNCH/docs"
cat >"$LAUNCH/pyproject.toml" <<'EOF'
[project]
name = "demo"
requires-python = ">=3.12"

[project.scripts]
demo-cli = "mypkg.cli:main"

[dependency-groups]
dev = ["pytest"]
docs = ["mkdocs"]
EOF
: >"$LAUNCH/src/mypkg/__main__.py"
printf '# /// script\n# dependencies = []\n# ///\nprint(1)\n' >"$LAUNCH/scripts/probe.py"
printf 'print(2)\n' >"$LAUNCH/scripts/plain.py"
printf '3.13\n' >"$LAUNCH/.python-version"
printf 'layout uv\nexport API_KEY=supersecret\nexport DEBUG_MODE=1\n' >"$LAUNCH/.envrc"

for name in verify run run-skill-generator; do
  ctx=$(manifest_context "$(manifest_event "$name" "$LAUNCH")")
  expect_has "/$name adds the console script" "$ctx" 'demo-cli = mypkg.cli:main'
  expect_has "/$name adds the __main__ package" "$ctx" 'python -m <package>'
done

ctx=$(manifest_context "$(manifest_event verify "$LAUNCH")")
expect_has "package name is listed" "$ctx" 'mypkg'
expect_has "PEP 723 script is listed" "$ctx" 'scripts/probe.py'
expect_lacks "script without a metadata block is not listed" "$ctx" 'plain.py'
expect_has "dependency groups are listed" "$ctx" 'dev, docs'
expect_has ".python-version is read" "$ctx" '.python-version: 3.13'
expect_has ".envrc variable names are listed" "$ctx" 'API_KEY, DEBUG_MODE'
expect_has ".envrc directives are listed" "$ctx" 'layout uv'
expect_lacks ".envrc values never appear" "$ctx" 'supersecret'

event_name=$(printf '%s' "$(manifest_event verify "$LAUNCH")" | "$MANIFEST" 2>/dev/null |
  jq -r '.hookSpecificOutput.hookEventName')
expect_has "output names the UserPromptExpansion event" "$event_name" 'UserPromptExpansion'

expect_has "a leading slash on the command name is accepted" \
  "$(manifest_context "$(manifest_event /verify "$LAUNCH")")" 'demo-cli'
expect_has "a subdirectory finds the parent pyproject.toml" \
  "$(manifest_context "$(manifest_event verify "$LAUNCH/docs")")" 'demo-cli'

for name in commit review prune running verify-all ''; do
  out=$(printf '%s' "$(manifest_event "$name" "$LAUNCH")" | "$MANIFEST" 2>/dev/null)
  expect_lacks "command '$name' prints nothing" "x$out" 'x{'
done

expect_lacks "no pyproject.toml prints nothing" \
  "x$(printf '%s' "$(manifest_event verify "$LAUNCH_BARE")" | "$MANIFEST" 2>/dev/null)" 'x{'

printf '[project\nname = ' >"$LAUNCH_BROKEN/pyproject.toml"
expect_has "a broken pyproject.toml is reported, not hidden" \
  "$(manifest_context "$(manifest_event verify "$LAUNCH_BROKEN")")" 'could not be parsed'

printf '[project]\nname = "big"\n[dependency-groups]\n' >"$LAUNCH_BIG/pyproject.toml"
for i in $(seq 1 200); do
  printf 'g%s = []\n' "$i" >>"$LAUNCH_BIG/pyproject.toml"
  printf '# /// script\n# ///\n' >"$LAUNCH_BIG/s$i.py"
done
big=$(manifest_context "$(manifest_event verify "$LAUNCH_BIG")")
expect_has "a large project is cut with a marker" "$big" 'and 192 more'
if ((${#big} <= 10000)) && (($(wc -l <<<"$big") <= 40)); then
  printf 'ok    %-52s\n' "output stays within 40 lines and 10,000 characters"
  ((pass++))
else
  printf 'FAIL  %-52s %s characters\n' "output stays within the caps" "${#big}"
  ((fail++))
fi

rc=0
printf 'not json' | "$MANIFEST" >/dev/null 2>&1 || rc=$?
check "malformed input exits non-zero" error "$( ((rc == 1)) && echo error || echo "allow:rc=$rc")"

if jq -e '.hooks.UserPromptExpansion[0].matcher
          | test("verify") and test("run-skill-generator")' "$HOOKS_JSON" >/dev/null; then
  printf 'ok    %-52s\n' "hooks.json matches the three skills"
  ((pass++))
else
  printf 'FAIL  %-52s\n' "hooks.json matches the three skills"
  ((fail++))
fi

if jq -e '.hooks.SessionStart == null' "$HOOKS_JSON" >/dev/null; then
  printf 'ok    %-52s\n' "hooks.json has no SessionStart hook"
  ((pass++))
else
  printf 'FAIL  %-52s\n' "hooks.json has no SessionStart hook"
  ((fail++))
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
((fail == 0))
