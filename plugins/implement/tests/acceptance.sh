#!/usr/bin/env bash
# Acceptance tests for the implement plugin's test-lock hook.
# Everything here is deterministic and free. The skills and the reviewer agents
# are model behaviour, so only their structure is checked here.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd -P -- "$HERE/.." && pwd -P)
readonly ROOT
readonly HOOK="$ROOT/hooks/test-lock.py"
readonly HOOKS_JSON="$ROOT/hooks/hooks.json"

pass=0
fail=0

# check <label> <expected> <actual>
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %-66s\n' "$1"
    ((pass++))
  else
    printf 'FAIL  %-66s expected %q, got %q\n' "$1" "$2" "$3"
    ((fail++))
  fi
}

# A fresh git-rooted project in a temp directory, with a valid marker.
PROJECT=$(mktemp -d)
trap 'rm -rf "$PROJECT"' EXIT
PROJECT=$(cd -P -- "$PROJECT" && pwd -P)
mkdir -p "$PROJECT/.git" "$PROJECT/.implement" "$PROJECT/src/pkg" "$PROJECT/tests/acceptance" "$PROJECT/docs"
readonly MARKER="$PROJECT/.implement/loop.json"

write_marker() {
  printf '%s' "$1" >"$MARKER"
}

readonly VALID='{"version":1,"protected":["tests/acceptance/**","tests/test_spec.py","docs/"]}'

# run <tool> <path-key> <path> <cwd>: prints stdout, stderr to $ERR, exit code to $RC
ERR=$(mktemp)
run() {
  local tool=$1 key=$2 path=$3 cwd=$4
  OUT=$(jq -nc --arg t "$tool" --arg k "$key" --arg p "$path" --arg c "$cwd" \
    '{hook_event_name:"PreToolUse",tool_name:$t,cwd:$c,tool_input:{($k):$p}}' |
    "$HOOK" 2>"$ERR")
  RC=$?
}

verdict() {
  jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"${OUT:-null}" 2>/dev/null || echo "allow"
}

expect_deny() { # label tool key path cwd
  run "$2" "$3" "$4" "$5"
  check "$1: denied" deny "$(verdict)"
  check "$1: exit 0 with JSON" 0 "$RC"
}

expect_allow() { # label tool key path cwd
  run "$2" "$3" "$4" "$5"
  check "$1: allowed" allow "$(verdict)"
  check "$1: stdout empty, exit 0" "0|" "$RC|$OUT"
}

# --- no marker ---------------------------------------------------------------
rm -f "$MARKER"
expect_allow "no marker, test path" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"

# --- valid marker ------------------------------------------------------------
write_marker "$VALID"
expect_deny "Edit on a globbed test file" Edit file_path "$PROJECT/tests/acceptance/test_a.py" "$PROJECT"
expect_deny "Write creating a new protected file" Write file_path "$PROJECT/tests/acceptance/sub/test_new.py" "$PROJECT"
expect_deny "Edit on an exact protected path" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"
expect_deny "directory glob with a trailing slash" Write file_path "$PROJECT/docs/design.md" "$PROJECT"
expect_deny "NotebookEdit through notebook_path" NotebookEdit notebook_path "$PROJECT/tests/acceptance/nb.ipynb" "$PROJECT"
expect_deny "the marker itself" Write file_path "$MARKER" "$PROJECT"
expect_deny "relative path from a subdirectory" Edit file_path "../../tests/test_spec.py" "$PROJECT/src/pkg"
expect_deny "cwd in a subdirectory finds the marker" Edit file_path "$PROJECT/tests/acceptance/test_a.py" "$PROJECT/src/pkg"

reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$OUT")
check "denial reason names the file" true "$([[ "$reason" == *"tests/acceptance/test_a.py"* ]] && echo true || echo false)"
check "denial reason says stop and ask the user" true "$([[ "$reason" == *"ask the user"* ]] && echo true || echo false)"

expect_allow "implementation file" Edit file_path "$PROJECT/src/pkg/module.py" "$PROJECT"
expect_allow "test outside the globs" Edit file_path "$PROJECT/tests/test_other.py" "$PROJECT"
expect_allow "bare glob does not reach subdirectories" Edit file_path "$PROJECT/tests/sub/test_spec.py" "$PROJECT"
expect_allow "path outside the project" Edit file_path "/tmp/not-in-project/tests/test_spec.py" "$PROJECT"

# The documented limit: only the file tools are guarded, so a Bash command that
# rewrites a protected test is not seen. This case pins that limit down.
run Bash command "sed -i '' s/x/y/ tests/test_spec.py" "$PROJECT"
check "limit: Bash rewrite of a locked test is not blocked" allow "$(verdict)"

# --- the guard fails open ----------------------------------------------------
write_marker '{"version":1,"protected":['
expect_allow "malformed JSON marker" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"
check "malformed marker is reported on stderr" true "$([[ "$(<"$ERR")" == *"guard off"* ]] && echo true || echo false)"

write_marker '{"version":2,"protected":["tests/**"]}'
expect_allow "wrong schema version" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"
check "wrong schema is reported on stderr" true "$([[ "$(<"$ERR")" == *"schema"* ]] && echo true || echo false)"

write_marker '{"version":1,"protected":[]}'
expect_allow "empty protected list" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"

write_marker '{"version":1,"protected":[1,2]}'
expect_allow "protected entries that are not strings" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"

write_marker '["not","an","object"]'
expect_allow "marker that is not an object" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"

write_marker "$VALID"
touch -t 202001010000 "$MARKER"
expect_allow "stale marker (older than 12 hours)" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"
check "stale marker is reported on stderr" true "$([[ "$(<"$ERR")" == *"ignored"* ]] && echo true || echo false)"
touch "$MARKER"
expect_deny "a fresh marker locks again" Edit file_path "$PROJECT/tests/test_spec.py" "$PROJECT"

# A marker above the git root must not affect the repository.
OUTER=$(mktemp -d)
OUTER=$(cd -P -- "$OUTER" && pwd -P)
mkdir -p "$OUTER/.implement" "$OUTER/repo/.git" "$OUTER/repo/tests"
printf '%s' '{"version":1,"protected":["**"]}' >"$OUTER/.implement/loop.json"
expect_allow "marker above the git root is ignored" Edit file_path "$OUTER/repo/tests/test_spec.py" "$OUTER/repo"
rm -rf "$OUTER"

for stdin in '' 'not json' '{"broken":' '[]' '{}' '{"cwd":"/nonexistent","tool_input":{"file_path":"/x"}}'; do
  OUT=$(printf '%s' "$stdin" | "$HOOK" 2>/dev/null)
  check "exit 0 and silent on stdin '${stdin:-<empty>}'" "0|" "$?|$OUT"
done

# --- hooks.json --------------------------------------------------------------
check "hooks.json: valid JSON" true "$(jq -e . "$HOOKS_JSON" >/dev/null 2>&1 && echo true || echo false)"
check "hooks.json: one event" PreToolUse "$(jq -r '.hooks | keys | join(" ")' "$HOOKS_JSON")"
check "hooks.json: matcher" "Edit|Write|NotebookEdit" "$(jq -r '.hooks.PreToolUse[0].matcher' "$HOOKS_JSON")"
check "hooks.json: exec form with uv" uv "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
check "hooks.json: script through CLAUDE_PLUGIN_ROOT" true \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].args | any(startswith("${CLAUDE_PLUGIN_ROOT}/hooks/"))' "$HOOKS_JSON")"
script_name=$(jq -r '.hooks.PreToolUse[0].hooks[0].args[-1] | sub("^\\$\\{CLAUDE_PLUGIN_ROOT\\}/"; "")' "$HOOKS_JSON")
check "hooks.json: the script it names exists" true "$([[ -f "$ROOT/$script_name" ]] && echo true || echo false)"
check "hooks.json: timeout set" true "$(jq -r '.hooks.PreToolUse[0].hooks[0].timeout | type == "number"' "$HOOKS_JSON")"

# --- agents ------------------------------------------------------------------
for agent in test-reviewer code-reviewer architecture-reviewer; do
  file="$ROOT/agents/$agent.md"
  fm=$(awk '/^---$/{n++; next} n==1' "$file")
  tools=$(sed -n 's/^tools: *//p' <<<"$fm")
  check "agent $agent: name matches file" "$agent" "$(sed -n 's/^name: *//p' <<<"$fm")"
  check "agent $agent: read-only tools" "Read, Grep, Glob" "$tools"
  check "agent $agent: sets maxTurns as a backstop" true \
    "$([[ "$fm" =~ (^|$'\n')maxTurns:\ [0-9]+ ]] && echo true || echo false)"
  check "agent $agent: does not drop CLAUDE.md" false \
    "$([[ "$fm" =~ (^|$'\n')omitClaudeMd: ]] && echo true || echo false)"
  check "agent $agent: no ignored plugin-agent field" false \
    "$([[ "$fm" =~ (^|$'\n')(hooks|mcpServers|permissionMode|initialPrompt): ]] && echo true || echo false)"
  check "agent $agent: tells the agent not to consult the advisor" true \
    "$(grep -q 'Do not consult the advisor' "$file" && echo true || echo false)"
  check "agent $agent: tells the agent not to delegate" true \
    "$(grep -q 'you do not delegate' "$file" && echo true || echo false)"
  check "agent $agent: names its verdict line" true \
    "$(grep -q 'Verdict: CLEAR' "$file" && grep -q 'Verdict: BLOCKED' "$file" && echo true || echo false)"
done

check "agent architecture-reviewer: names both modes" true \
  "$(grep -q 'Mode: design' "$ROOT/agents/architecture-reviewer.md" && grep -q 'Mode: change' "$ROOT/agents/architecture-reviewer.md" && echo true || echo false)"
check "agent test-reviewer: names both modes" true \
  "$(grep -q 'Mode: pre-lock' "$ROOT/agents/test-reviewer.md" && grep -q 'Mode: change' "$ROOT/agents/test-reviewer.md" && echo true || echo false)"
check "design review brief starts with the mode line" true \
  "$(grep -q '^Mode: design$' "$ROOT/skills/architecture-design/references/design-review-brief.md" && echo true || echo false)"
check "reviewer briefs carry the pre-lock and change mode lines" true \
  "$(f="$ROOT/skills/implement/references/reviewer-briefs.md"; grep -q '^Mode: pre-lock$' "$f" && grep -q '^Mode: change$' "$f" && echo true || echo false)"

# --- whole plugin ------------------------------------------------------------
check "manifest: depends on orchestration" '["orchestration"]' "$(jq -c '.dependencies' "$ROOT/.claude-plugin/plugin.json")"
check "manifest: no version field" null "$(jq -r '.version // "null"' "$ROOT/.claude-plugin/plugin.json")"
check "hook: requires-python is >=3.14" true \
  "$(rg -q '^# requires-python = ">=3\.14"$' "$HOOK" && echo true || echo false)"
check "hook: executable" true "$([[ -x "$HOOK" ]] && echo true || echo false)"
check "no ../ path out of the plugin" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' --glob '!evals/results/**' '\.\./' . || true)"
check "no em or en dash" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' --glob '!evals/results/**' '[—–]' . || true)"
check "agents named only with the implement: prefix" "" \
  "$(rg -n -P '(?<!implement:)(?<![\w-])(test-reviewer|code-reviewer|architecture-reviewer)(?![\w-])' "$ROOT/skills" --glob '!**/references/**' | grep -v '\.claude/agents/' || true)"
check "orchestration agents named with their prefix" "" \
  "$(rg -n -P '(?<!orchestration:)(?<![\w-])(repo-map|call-sites|api-docs)(?![\w-])' "$ROOT/skills" "$ROOT/agents" | grep -v 'orchestration:' || true)"

rm -f "$ERR"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
