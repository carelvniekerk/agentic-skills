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
expect_deny "TypeScript test file under the glob" Edit file_path "$PROJECT/tests/acceptance/orders.test.ts" "$PROJECT"
expect_deny "new TypeScript test in a subdirectory" Write file_path "$PROJECT/tests/acceptance/api/cart.test.tsx" "$PROJECT"
expect_deny "the marker itself" Write file_path "$MARKER" "$PROJECT"
expect_deny "relative path from a subdirectory" Edit file_path "../../tests/test_spec.py" "$PROJECT/src/pkg"
expect_deny "cwd in a subdirectory finds the marker" Edit file_path "$PROJECT/tests/acceptance/test_a.py" "$PROJECT/src/pkg"

reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$OUT")
check "denial reason names the file" true "$([[ "$reason" == *"tests/acceptance/test_a.py"* ]] && echo true || echo false)"
check "denial reason says stop and ask the user" true "$([[ "$reason" == *"ask the user"* ]] && echo true || echo false)"

expect_allow "implementation file" Edit file_path "$PROJECT/src/pkg/module.py" "$PROJECT"
expect_allow "TypeScript implementation file" Edit file_path "$PROJECT/src/pkg/orders.ts" "$PROJECT"
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
check "hooks.json: two events" "PreToolUse SessionStart" "$(jq -r '.hooks | keys | join(" ")' "$HOOKS_JSON")"
check "hooks.json: matcher" "Edit|Write|NotebookEdit" "$(jq -r '.hooks.PreToolUse[0].matcher' "$HOOKS_JSON")"
check "hooks.json: exec form with uv" uv "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"
check "hooks.json: script through CLAUDE_PLUGIN_ROOT" true \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].args | any(startswith("${CLAUDE_PLUGIN_ROOT}/hooks/"))' "$HOOKS_JSON")"
script_name=$(jq -r '.hooks.PreToolUse[0].hooks[0].args[-1] | sub("^\\$\\{CLAUDE_PLUGIN_ROOT\\}/"; "")' "$HOOKS_JSON")
check "hooks.json: the script it names exists" true "$([[ -f "$ROOT/$script_name" ]] && echo true || echo false)"
check "hooks.json: timeout set" true "$(jq -r '.hooks.PreToolUse[0].hooks[0].timeout | type == "number"' "$HOOKS_JSON")"
check "hooks.json: drift gate runs on startup only" startup "$(jq -r '.hooks.SessionStart[0].matcher' "$HOOKS_JSON")"
check "hooks.json: drift gate runs the scanner in gate mode" "gate" "$(jq -r '.hooks.SessionStart[0].hooks[0].args[-1]' "$HOOKS_JSON")"
gate_script=$(jq -r '.hooks.SessionStart[0].hooks[0].args[-2] | sub("^\\$\\{CLAUDE_PLUGIN_ROOT\\}/"; "")' "$HOOKS_JSON")
check "hooks.json: the drift gate script exists and is executable" true "$([[ -x "$ROOT/$gate_script" ]] && echo true || echo false)"

# --- agents ------------------------------------------------------------------
for agent in test-reviewer code-reviewer architecture-reviewer drift-reviewer; do
  file="$ROOT/agents/$agent.md"
  fm=$(awk '/^---$/{n++; next} n==1' "$file")
  tools=$(sed -n 's/^tools: *//p' <<<"$fm")
  check "agent $agent: name matches file" "$agent" "$(sed -n 's/^name: *//p' <<<"$fm")"
  check "agent $agent: read-only tools" "Read, Grep, Glob, mcp__savvy-progress__step" "$tools"
  check "agent $agent: no write, Agent or Skill tool" false \
    "$([[ "$tools" =~ (Write|Edit|NotebookEdit|Bash|Agent|Skill) ]] && echo true || echo false)"
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

# --- drift-scan.py and the drift gate -----------------------------------------
readonly SCAN="$ROOT/skills/drift-check/scripts/drift-scan.py"
UV=$(command -v uv)
readonly UV
# A PATH without the user's tool directories, so a boundary tool that is
# installed on this machine cannot make the "tool absent" case pass or fail.
readonly BARE_PATH="/usr/bin:/bin"

scan_in() { # dir args...: JSON to $SCAN_OUT, summary to $ERR, exit code to $RC
  local dir=$1
  shift
  SCAN_OUT=$(cd "$dir" && PATH="$BARE_PATH:$(dirname "$UV")" "$SCAN" scan "$@" 2>"$ERR")
  RC=$?
}

gate_in() { # dir: stdout to $GATE_OUT, exit code to $RC
  GATE_OUT=$(jq -nc --arg c "$1" '{hook_event_name:"SessionStart",source:"startup",cwd:$c}' | "$SCAN" gate 2>"$ERR")
  RC=$?
}

# A git project with one implemented design, one test file and one source file.
make_drift_repo() {
  local dir=$1
  mkdir -p "$dir/docs/design" "$dir/src" "$dir/tests/acceptance"
  git -C "$dir" init -q
  cat >"$dir/docs/design/cart.md" <<'DESIGN'
---
status: implemented
tests:
  - tests/acceptance/test_cart.py
---
# Cart

The module `src/cart.py` holds `compute_total()`.
It replaced `src/gone.py`, and `vanished_helper()` is called from it.

| ID | Criterion | Level |
| --- | --- | --- |
| AC-1 | Empty cart totals zero | unit |
| AC-2 | Negative price is rejected | unit |
DESIGN
  printf 'def compute_total(items):\n    return sum(items)\n' >"$dir/src/cart.py"
  printf 'def test_ac_1_empty_cart_is_zero():\n    pass\n\n\ndef test_ac_9_nothing_requires_this():\n    pass\n' \
    >"$dir/tests/acceptance/test_cart.py"
}

DRIFT=$(mktemp -d)
DRIFT=$(cd -P -- "$DRIFT" && pwd -P)
trap 'rm -rf "$PROJECT" "$DRIFT"' EXIT
make_drift_repo "$DRIFT/dirty"
scan_in "$DRIFT/dirty"
check "scan: exit 1 when there are findings" 1 "$RC"
kinds() { jq -r --arg k "$1" '[.findings[] | select(.kind == $k)] | length' <<<"$SCAN_OUT"; }
check "scan: MISSING for a path that does not exist" true \
  "$(jq -r '[.findings[] | select(.kind == "MISSING" and (.detail | contains("src/gone.py")))] | length == 1' <<<"$SCAN_OUT")"
check "scan: MISSING carries the design line number" 9 \
  "$(jq -r '.findings[] | select(.detail | contains("src/gone.py")) | .line' <<<"$SCAN_OUT")"
check "scan: MISSING for an identifier in no source file" true \
  "$(jq -r '[.findings[] | select(.kind == "MISSING" and (.detail | contains("vanished_helper")))] | length == 1' <<<"$SCAN_OUT")"
check "scan: an identifier that exists is not reported" 0 \
  "$(jq -r '[.findings[] | select(.detail | contains("compute_total"))] | length' <<<"$SCAN_OUT")"
check "scan: UNTESTED for a criterion with no test ID" true \
  "$(jq -r '[.findings[] | select(.kind == "UNTESTED" and (.detail | startswith("AC-2")))] | length == 1' <<<"$SCAN_OUT")"
check "scan: the tested criterion is not UNTESTED" 1 "$(kinds UNTESTED)"
check "scan: ORPHAN for a test ID in no criterion" true \
  "$(jq -r '[.findings[] | select(.kind == "ORPHAN" and (.detail | startswith("AC-9")))] | length == 1' <<<"$SCAN_OUT")"
check "scan: summary on stderr" true "$([[ "$(<"$ERR")" == *"UNTESTED"* ]] && echo true || echo false)"
check "scan: writes nothing into the repository" "" "$(git -C "$DRIFT/dirty" status --porcelain | grep -v '^?? \(docs\|src\|tests\)/' || true)"
check "scan: refs are the existing referenced files and tests" '["src/cart.py","tests/acceptance/test_cart.py"]' \
  "$(jq -c '.designs[0].referenced_files' <<<"$SCAN_OUT")"

make_drift_repo "$DRIFT/clean"
sed -i.bak -e '/src\/gone.py/d' -e '/AC-2/d' "$DRIFT/clean/docs/design/cart.md"
rm "$DRIFT/clean/docs/design/cart.md.bak"
printf 'def vanished_helper():\n    pass\n' >>"$DRIFT/clean/src/cart.py"
printf '\nThe module `src/cart.py` calls `vanished_helper()`.\n' >>"$DRIFT/clean/docs/design/cart.md"
sed -i.bak '/test_ac_9/,$d' "$DRIFT/clean/tests/acceptance/test_cart.py"
rm "$DRIFT/clean/tests/acceptance/test_cart.py.bak"
scan_in "$DRIFT/clean"
check "scan: exit 0 on a clean repository" 0 "$RC"
check "scan: clean design is reported CLEAR" true "$([[ "$(<"$ERR")" == *"CLEAR"* ]] && echo true || echo false)"

scan_in "$DRIFT/clean" "$DRIFT/does-not-exist.md"
check "scan: exit 2 on an error that is not a finding" 2 "$RC"

# Status filter
make_drift_repo "$DRIFT/status"
sed -i.bak 's/^status: implemented/status: draft/' "$DRIFT/status/docs/design/cart.md"
rm "$DRIFT/status/docs/design/cart.md.bak"
scan_in "$DRIFT/status"
check "scan: a draft design is skipped" false "$(jq -r '.designs[0].scanned' <<<"$SCAN_OUT")"
check "scan: the skip says why" true "$([[ "$(jq -r '.designs[0].skip_reason' <<<"$SCAN_OUT")" == *draft* ]] && echo true || echo false)"
check "scan: a skipped design gives exit 0" 0 "$RC"
sed -i.bak 's/^status: draft/status: approved/' "$DRIFT/status/docs/design/cart.md"
rm "$DRIFT/status/docs/design/cart.md.bak"
scan_in "$DRIFT/status"
check "scan: an approved design is skipped as not marked implemented" true \
  "$([[ "$(jq -r '.designs[0].skip_reason' <<<"$SCAN_OUT")" == *"not marked implemented"* ]] && echo true || echo false)"

# Boundary tool absent: NOT RUN, nothing installed
make_drift_repo "$DRIFT/boundary"
printf '[importlinter]\nroot_package = cart\n' >"$DRIFT/boundary/.importlinter"
printf '\nBoundaries are enforced by import-linter.\n' >>"$DRIFT/boundary/docs/design/cart.md"
scan_in "$DRIFT/boundary"
check "scan: NOT RUN when the boundary tool is absent" true \
  "$(jq -r '[.not_run[] | select(.tool == "import-linter" and (.reason | length) > 0)] | length == 1' <<<"$SCAN_OUT")"
check "scan: the absent tool is not a finding" 0 "$(jq -r '[.findings[] | select(.kind == "BOUNDARY")] | length' <<<"$SCAN_OUT")"
check "scan: the summary says NOT RUN" true "$([[ "$(<"$ERR")" == *"NOT RUN"* ]] && echo true || echo false)"
check "scan: installs nothing" "" "$(find "$DRIFT/boundary" -maxdepth 1 \( -name .venv -o -name node_modules -o -name uv.lock \) -print)"

# A failing boundary tool is reported verbatim
mkdir -p "$DRIFT/boundary/.venv/bin"
printf '#!/bin/sh\necho "Contracts: 1 broken"\nexit 1\n' >"$DRIFT/boundary/.venv/bin/lint-imports"
chmod +x "$DRIFT/boundary/.venv/bin/lint-imports"
scan_in "$DRIFT/boundary"
check "scan: BOUNDARY finding quotes the tool output" true \
  "$(jq -r '[.findings[] | select(.kind == "BOUNDARY" and (.detail | contains("Contracts: 1 broken")))] | length == 1' <<<"$SCAN_OUT")"

# Noise rules: what a design mentions without it being drift
make_drift_repo "$DRIFT/noise"
mkdir -p "$DRIFT/sibling" "$DRIFT/noise/src/pkg"
printf 'def keep():\n    pass\n' >"$DRIFT/noise/src/pkg/ports.py"
cat >"$DRIFT/noise/docs/design/cart.md" <<'DESIGN'
---
status: implemented
tests:
  - tests/acceptance/test_cart.py
---
# Cart

Partial package path `pkg/ports.py` exists as `src/pkg/ports.py`.
Runtime output `inventory.json` and sibling path `sibling/mod.py` are not drift.
An example path `a/x.pptx` and a config key `source_modules` are not drift either.
A renamed `renamed_func()` and a deleted `src/real_gone.py` are drift.

| ID | Criterion | Level |
| --- | --- | --- |
| AC-1 | Empty cart totals zero | unit |
DESIGN
scan_in "$DRIFT/noise"
check "scan noise: only the two real misses are reported" 2 "$(kinds MISSING)"
check "scan noise: the deleted source file is reported" true \
  "$(jq -r '[.findings[] | select(.detail | contains("src/real_gone.py"))] | length == 1' <<<"$SCAN_OUT")"
check "scan noise: a call to a renamed function is reported" true \
  "$(jq -r '[.findings[] | select(.detail | contains("renamed_func"))] | length == 1' <<<"$SCAN_OUT")"
check "scan noise: a partial package path matches a deeper file" 0 \
  "$(jq -r '[.findings[] | select(.detail | contains("pkg/ports.py"))] | length' <<<"$SCAN_OUT")"

# The gate
make_drift_repo "$DRIFT/gate"
mkdir "$DRIFT/nodesign"
git -C "$DRIFT/nodesign" init -q
gate_in "$DRIFT/nodesign"
check "gate: silent without a design directory" "" "$GATE_OUT"
check "gate: exit 0 without a design directory" 0 "$RC"
mkdir -p "$DRIFT/nodesign/docs/design"
cp "$DRIFT/status/docs/design/cart.md" "$DRIFT/nodesign/docs/design/cart.md"
gate_in "$DRIFT/nodesign"
check "gate: silent when no design is implemented" "" "$GATE_OUT"

gate_in "$DRIFT/gate"
check "gate: fires on the first run, with no state" SessionStart "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$GATE_OUT")"
msg=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$GATE_OUT")
check "gate: the message names /implement:drift-check" true "$([[ "$msg" == *"/implement:drift-check"* ]] && echo true || echo false)"
check "gate: the message tells the session not to start an agent" true \
  "$([[ "$msg" == *"Do not start the check or any agent"* ]] && echo true || echo false)"
check "gate: writes no drift state" false "$([[ -e "$DRIFT/gate/.implement/drift-state.json" ]] && echo true || echo false)"
check "gate: notes the proposal in its own cooldown file" true "$([[ -f "$DRIFT/gate/.implement/drift-gate.json" ]] && echo true || echo false)"
gate_in "$DRIFT/gate"
check "gate: silent at the next startup within the cooldown" "" "$GATE_OUT"
rm -f "$DRIFT/gate/.implement/drift-gate.json"
printf 'not json{' >"$DRIFT/gate/.implement/drift-gate.json"
gate_in "$DRIFT/gate"
check "gate: a corrupt cooldown file does not silence it" SessionStart "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$GATE_OUT")"
old_stamp=$(($(date +%s) - 2 * 86400))
printf '{"proposed_at": %s}\n' "$old_stamp" >"$DRIFT/gate/.implement/drift-gate.json"
gate_in "$DRIFT/gate"
check "gate: fires again once the cooldown has passed" SessionStart "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$GATE_OUT")"
check "gate: starts nothing, one JSON object only" 1 "$(jq -s 'length' <<<"$GATE_OUT")"

(cd "$DRIFT/gate" && "$SCAN" record >/dev/null 2>&1)
check "record: writes the state file" true "$([[ -f "$DRIFT/gate/.implement/drift-state.json" ]] && echo true || echo false)"
check "record: keeps .implement out of git" "" "$(git -C "$DRIFT/gate" status --porcelain | grep '\.implement' || true)"
gate_in "$DRIFT/gate"
check "gate: silent right after a pass" "" "$GATE_OUT"

printf '\n# changed\n' >>"$DRIFT/gate/src/cart.py"
gate_in "$DRIFT/gate"
check "gate: silent when files changed but the pass is under 7 days old" "" "$GATE_OUT"

state="$DRIFT/gate/.implement/drift-state.json"
old=$(($(date +%s) - 10 * 86400))
jq --argjson t "$old" '.checked_at = $t' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
rm -f "$DRIFT/gate/.implement/drift-gate.json"
gate_in "$DRIFT/gate"
check "gate: fires when 7 days passed and a referenced file changed" SessionStart \
  "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$GATE_OUT")"

(cd "$DRIFT/gate" && "$SCAN" record >/dev/null 2>&1)
jq --argjson t "$old" '.checked_at = $t' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
gate_in "$DRIFT/gate"
check "gate: silent when 7 days passed and nothing changed" "" "$GATE_OUT"

printf 'not json{' >"$state"
gate_in "$DRIFT/gate"
check "gate: silent on a corrupt state file" "" "$GATE_OUT"
check "gate: exit 0 on a corrupt state file" 0 "$RC"
printf '{"version":1}' >"$state"
gate_in "$DRIFT/gate"
check "gate: silent on a state file with the wrong shape" "" "$GATE_OUT"

# --- ticket skill --------------------------------------------------------------
readonly TICKET="$ROOT/skills/ticket/SKILL.md"
ticket_fm=$(awk '/^---$/{n++; next} n==1' "$TICKET")
check "ticket: name matches directory" ticket "$(sed -n 's/^name: *//p' <<<"$ticket_fm")"
check "ticket: no Agent tool, so no subagent" false \
  "$(sed -n 's/^allowed-tools: *//p' <<<"$ticket_fm" | grep -qw 'Agent' && echo true || echo false)"
check "ticket: has a strict prohibitions table" true "$(grep -q '^## Strict prohibitions$' "$TICKET" && echo true || echo false)"
check "ticket: marks the single provider hook" true "$(grep -q '^## Delivering the ticket$' "$TICKET" && echo true || echo false)"
check "ticket: has a readiness gate before writing" true "$(grep -q '^## Step 4: readiness gate$' "$TICKET" && echo true || echo false)"
check "ticket: template has no acceptance criterion IDs" "" "$(rg -n 'AC-[0-9n]' "$ROOT/skills/ticket/references/ticket-template.md" || true)"
check "ticket: template frontmatter has the five keys" "title slug status date author" \
  "$(awk '/^---$/{n++; next} n==1' "$ROOT/skills/ticket/references/ticket-template.md" | sed -n 's/^\([a-z]*\):.*/\1/p' | paste -sd' ' -)"
check "ticket: lenses file lists six lenses" 6 \
  "$(grep -cE '^\| (Build or buy|Cost and quota|Ergonomics|Migration and compatibility|Observability|Maintenance) \|' "$ROOT/skills/ticket/references/lenses.md")"
check "ticket: THIRD_PARTY credits the upstream, licence and commit" true \
  "$(f="$ROOT/THIRD_PARTY.md"; grep -q 'github.com/google/elephant-goldfish-model' "$f" && grep -q 'Apache-2.0' "$f" && grep -qE '[0-9a-f]{40}' "$f" && grep -q 'Adapted' "$f" && echo true || echo false)"
check "ticket: architecture-design Phase 0 reads a ticket" true \
  "$(grep -q 'implement:ticket' "$ROOT/skills/architecture-design/SKILL.md" && echo true || echo false)"
check "ticket: design template records the ticket path" true \
  "$(grep -q '^ticket: ' "$ROOT/skills/architecture-design/references/design-template.md" && echo true || echo false)"
for case in ticket-fires-feature-idea ticket-fires-screenshot ticket-fires-german ticket-near-miss-design ticket-near-miss-build ticket-near-miss-review-diff; do
  check "ticket eval $case: prompt and a grader exist" true \
    "$([[ -f "$ROOT/evals/$case/prompt.md" ]] && compgen -G "$ROOT/evals/$case/graders/*.md" >/dev/null && echo true || echo false)"
done

# --- git:pr drift step (structure only, an eval cannot see a skipped step) ----
readonly GIT_PR="$ROOT/../git/skills/pr/SKILL.md"
check "git:pr: drift step runs only for an implemented design" true \
  "$(grep -q 'only if the repository has a design document with `status: implemented`' "$GIT_PR" && echo true || echo false)"
check "git:pr: drift step is skipped silently when none is implemented" true \
  "$(grep -q 'Skip this step silently when no design is implemented' "$GIT_PR" && echo true || echo false)"
check "git: manifest depends on implement" '["implement"]' "$(jq -c '.dependencies' "$ROOT/../git/.claude-plugin/plugin.json")"
check "git: manifest has no version field" null "$(jq -r '.version // "null"' "$ROOT/../git/.claude-plugin/plugin.json")"

# --- whole plugin ------------------------------------------------------------
check "manifest: dependencies" '["orchestration","egm","python-quality","nodejs-quality"]' "$(jq -c '.dependencies' "$ROOT/.claude-plugin/plugin.json")"
check "marketplace: egm is pinned by SHA" true \
  "$(jq -e '.plugins[] | select(.name == "egm") | .source | (.source == "github" and (.sha | test("^[0-9a-f]{40}$")))' "$ROOT/../../.claude-plugin/marketplace.json" >/dev/null && echo true || echo false)"
check "marketplace: every implement dependency is listed" "" \
  "$(for d in $(jq -r '.dependencies[]' "$ROOT/.claude-plugin/plugin.json"); do jq -e --arg d "$d" '.plugins[] | select(.name == $d)' "$ROOT/../../.claude-plugin/marketplace.json" >/dev/null || echo "$d"; done)"
check "manifest: no version field" null "$(jq -r '.version // "null"' "$ROOT/.claude-plugin/plugin.json")"
check "hook: requires-python is >=3.14" true \
  "$(rg -q '^# requires-python = ">=3\.14"$' "$HOOK" && echo true || echo false)"
check "hook: executable" true "$([[ -x "$HOOK" ]] && echo true || echo false)"
check "no ../ path out of the plugin" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' --glob '!evals/results/**' '\.\./' . || true)"
check "no em or en dash" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' --glob '!evals/results/**' '[—–]' . || true)"
check "agents named only with the implement: prefix" "" \
  "$(rg -n -P '(?<!implement:)(?<![\w-])(test-reviewer|code-reviewer|architecture-reviewer|drift-reviewer)(?![\w-])' "$ROOT/skills" --glob '!**/references/**' | grep -v '\.claude/agents/' || true)"
check "orchestration agents named with their prefix" "" \
  "$(rg -n -P '(?<!orchestration:)(?<![\w-])(repo-map|call-sites|api-docs)(?![\w-])' "$ROOT/skills" "$ROOT/agents" | grep -v 'orchestration:' || true)"

rm -f "$ERR"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
