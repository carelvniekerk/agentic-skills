#!/usr/bin/env bash
# Acceptance tests for the orchestration plugin.
# Everything here is deterministic and free. The Sonnet gate and the Stop check
# are model calls, so their verdicts are probed by prompt-probe.sh instead.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd -P -- "$HERE/.." && pwd -P)
readonly ROOT
readonly HOOKS_JSON="$ROOT/hooks/hooks.json"
readonly SESSION_HOOK="$ROOT/hooks/session-context.py"
readonly GRAPH_HOOK="$ROOT/hooks/graph-index.py"
readonly MCP_JSON="$ROOT/.mcp.json"

pass=0
fail=0

# check <label> <expected> <actual>
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %-62s\n' "$1"
    ((pass++))
  else
    printf 'FAIL  %-62s expected %q, got %q\n' "$1" "$2" "$3"
    ((fail++))
  fi
}

# --- session-context.py ------------------------------------------------------
out=$(printf '%s' '{"hook_event_name":"SessionStart"}' | "$SESSION_HOOK" 2>/dev/null)
check "session-context: exit code" 0 $?
check "session-context: stdout is one JSON document" true "$(jq -e . <<<"$out" >/dev/null 2>&1 && echo true || echo false)"
check "session-context: event name" SessionStart "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")"
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
for name in orchestration:repo-map orchestration:call-sites orchestration:api-docs orchestration:delegate; do
  check "session-context: names $name" true "$([[ "$ctx" == *"$name"* ]] && echo true || echo false)"
done
check "session-context: facts, no imperative opener" false "$([[ "$ctx" =~ ^(Use|Always|Never|You must) ]] && echo true || echo false)"
for stdin in '' 'not json' '{"broken":'; do
  printf '%s' "$stdin" | "$SESSION_HOOK" >/dev/null 2>&1
  check "session-context: exit 0 on stdin '${stdin:-<empty>}'" 0 $?
done

# --- hooks.json --------------------------------------------------------------
check "hooks.json: valid JSON" true "$(python3 -m json.tool "$HOOKS_JSON" >/dev/null 2>&1 && echo true || echo false)"
check "hooks.json: events" "PreToolUse SessionStart Stop" "$(jq -r '.hooks | keys | join(" ")' "$HOOKS_JSON")"
check "SessionStart: exec form" "uv" "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON")"
check "SessionStart: script through CLAUDE_PLUGIN_ROOT" true \
  "$(jq -r '.hooks.SessionStart[0].hooks[0].args | any(startswith("${CLAUDE_PLUGIN_ROOT}/"))' "$HOOKS_JSON")"

check "PreToolUse: matcher groups" "Agent Bash" "$(jq -r '[.hooks.PreToolUse[].matcher] | sort | join(" ")' "$HOOKS_JSON")"
check "PreToolUse: six handlers" 6 "$(jq '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks) | length' "$HOOKS_JSON")"
check "PreToolUse: one rule per handler" \
  'Bash(curl *)|Bash(git clean *)|Bash(git push *)|Bash(git reset *)|Bash(rm *)|Bash(sudo *)' \
  "$(jq -r '[(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks)[].if] | sort | join("|")' "$HOOKS_JSON")"
check "PreToolUse: handler fields identical" '["prompt|claude-sonnet-5-5|true|30|Sonnet gate"]' \
  "$(jq -c '[(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks)[] | "\(.type)|\(.model)|\(.continueOnBlock)|\(.timeout)|\(.statusMessage)"] | unique' "$HOOKS_JSON")"
check "PreToolUse: one shared prompt" 1 "$(jq '[(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks)[].prompt] | unique | length' "$HOOKS_JSON")"
check "PreToolUse: prompt reads \$ARGUMENTS" true "$(jq -r '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks)[0].prompt | contains("$ARGUMENTS")' "$HOOKS_JSON")"

check "Stop: one handler, agent type" "1 agent" \
  "$(jq -r '.hooks.Stop | "\(map(.hooks | length) | add) \(.[0].hooks[0].type)"' "$HOOKS_JSON")"
check "Stop: model claude-sonnet-5-5" claude-sonnet-5-5 "$(jq -r '.hooks.Stop[0].hooks[0].model' "$HOOKS_JSON")"
for needle in stop_hook_active transcript_path CLAUDE.md 'Run the relevant tests or checks' 'corrected text only' '$ARGUMENTS'; do
  check "Stop: prompt mentions $needle" true \
    "$(jq -r --arg n "$needle" '.hooks.Stop[0].hooks[0].prompt | contains($n)' "$HOOKS_JSON")"
done

# --- code graph -------------------------------------------------------------
check ".mcp.json: codebase-memory with the read-only analysis profile" "codebase-memory-mcp --tool-profile=analysis" \
  "$(jq -r '.mcpServers["codebase-memory"] | "\(.command) \(.args | join(" "))"' "$MCP_JSON")"
check "Agent hook: exec form through CLAUDE_PLUGIN_ROOT" "uv|true|120" \
  "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[0] | "\(.command)|\(.args | any(. == "${CLAUDE_PLUGIN_ROOT}/hooks/graph-index.py"))|\(.timeout)"' "$HOOKS_JSON")"

# graph_case <label> <stdin>: the hook must exit 0 and print nothing.
graph_case() {
  local out rc
  out=$(printf '%s' "$2" | "$GRAPH_HOOK" 2>/dev/null)
  rc=$?
  check "graph-index: $1" "0|" "$rc|$out"
}
NOGIT=$(mktemp -d "${TMPDIR:-/tmp}/graph-index-nogit.XXXXXX")
trap 'rm -rf "$NOGIT"' EXIT
graph_case "other agent is ignored" '{"cwd":"/tmp","tool_input":{"subagent_type":"Explore"}}'
graph_case "non-JSON stdin" 'not json'
graph_case "JSON array stdin" '[]'
graph_case "missing tool_input" '{"cwd":"/tmp"}'
graph_case "outside a git repository" "{\"cwd\":\"$NOGIT\",\"tool_input\":{\"subagent_type\":\"orchestration:repo-map\"}}"
out=$(printf '%s' "{\"cwd\":\"$ROOT\",\"tool_input\":{\"subagent_type\":\"orchestration:repo-map\"}}" |
  PATH=/usr/bin:/bin "$(command -v uv)" run --script "$GRAPH_HOOK" 2>/dev/null)
check "graph-index: binary missing exits 0 silently" "0|" "$?|$out"

# The analysis profile's 13 tools; anything else (index, delete, ADR writes) must not reach an agent.
readonly ANALYSIS_TOOLS="search_graph query_graph trace_path get_code_snippet get_file_outline get_graph_schema compare_graphs get_architecture search_code list_projects index_status check_index_coverage detect_changes"
for agent in repo-map call-sites; do
  graph_tools=$(sed -n 's/^tools: *//p' "$ROOT/agents/$agent.md" | tr ',' '\n' | sed -n 's/^ *mcp__plugin_orchestration_codebase-memory__//p')
  outside=""
  for t in $graph_tools; do [[ " $ANALYSIS_TOOLS " == *" $t "* ]] || outside+="$t "; done
  check "agent $agent: graph tools are read-only analysis tools" "" "$outside"
  check "agent $agent: has graph tools" true "$([[ -n "$graph_tools" ]] && echo true || echo false)"
done

# A global ruff target of 3.14 rewrites except (A, B) into a 3.14-only form.
check "hooks: no unparenthesised multi-exception except" "" \
  "$(rg -n '^\s*except [A-Za-z_.]+, ' "$ROOT/hooks" || true)"

# --- agents ------------------------------------------------------------------
for agent in repo-map call-sites api-docs; do
  file="$ROOT/agents/$agent.md"
  fm=$(awk '/^---$/{n++; next} n==1' "$file")
  tools=$(sed -n 's/^tools: *//p' <<<"$fm")
  check "agent $agent: model haiku" haiku "$(sed -n 's/^model: *//p' <<<"$fm")"
  check "agent $agent: name matches file" "$agent" "$(sed -n 's/^name: *//p' <<<"$fm")"
  check "agent $agent: no write, shell or delegation tool" false \
    "$([[ ", $tools," =~ ,\ (Write|Edit|NotebookEdit|Bash|Agent), ]] && echo true || echo false)"
  check "agent $agent: no ignored plugin-agent field" false \
    "$([[ "$fm" =~ (^|$'\n')(hooks|mcpServers|permissionMode|initialPrompt): ]] && echo true || echo false)"
  check "agent $agent: tells the agent not to consult the advisor" true \
    "$(grep -q 'Do not consult the advisor' "$file" && echo true || echo false)"
done

# --- whole plugin ------------------------------------------------------------
check "no ../ path out of the plugin" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' '\.\./' . || true)"
# tests/ is excluded because this file holds the pattern itself.
check "no em or en dash" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' '[—–]' . || true)"
# The setup skill names the old bare files under ~/.claude/agents/ on purpose.
check "agents named only with the orchestration: prefix" "" \
  "$(rg -n -P '(?<!orchestration:)(?<![\w-])(repo-map|call-sites|api-docs)(?![\w-])' "$ROOT/skills" "$ROOT/hooks" --glob '!*.json' | grep -v '\.claude/agents/' || true)"
for script in "$SESSION_HOOK" "$GRAPH_HOOK" "$HERE/acceptance.sh" "$HERE/prompt-probe.sh" "$HERE/stop-probe.sh"; do
  check "executable: ${script#"$ROOT"/}" true "$([[ -x "$script" ]] && echo true || echo false)"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
