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

check "PreToolUse: matcher groups" "Bash" "$(jq -r '[.hooks.PreToolUse[].matcher] | sort | join(" ")' "$HOOKS_JSON")"
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
check ".mcp.json: one Graphicle server, fixed to this folder's project" "graphicle mcp --tools all --project ." \
  "$(jq -r '.mcpServers.graphicle | "\(.command) \(.args | join(" "))"' "$MCP_JSON")"
check ".mcp.json: only the graphicle server" graphicle "$(jq -r '.mcpServers | keys | join(" ")' "$MCP_JSON")"
# --or-workspace would serve every synced client repository, and --allow-learning adds the write tools.
check ".mcp.json: no workspace or learning flag" false \
  "$(jq -r '.mcpServers.graphicle.args | any(. == "--or-workspace" or . == "--workspace" or . == "--allow-learning")' "$MCP_JSON")"
check "hooks.json: no graph-index hook" false "$(jq -r '[.. | strings] | any(contains("graph-index"))' "$HOOKS_JSON")"

# --tools all publishes 23 tools, graph_link (which persists edges) among them, so an agent may list only these read tools.
readonly GRAPH_READ_TOOLS="repository_status repository_files query_graph get_node get_neighbors shortest_path get_community god_nodes graph_stats"
for agent in repo-map call-sites; do
  graph_tools=$(sed -n 's/^tools: *//p' "$ROOT/agents/$agent.md" | tr ',' '\n' | sed -n 's/^ *mcp__plugin_orchestration_graphicle__//p')
  outside=""
  for t in $graph_tools; do [[ " $GRAPH_READ_TOOLS " == *" $t "* ]] || outside+="$t "; done
  check "agent $agent: graph tools are Graphicle read tools" "" "$outside"
  check "agent $agent: has graph tools" true "$([[ -n "$graph_tools" ]] && echo true || echo false)"
  check "agent $agent: no codebase-memory tool left" false "$(grep -q 'codebase-memory' "$ROOT/agents/$agent.md" && echo true || echo false)"
  missing=""
  for t in $graph_tools; do grep -q "mcp__plugin_orchestration_graphicle__$t" "$ROOT/skills/setup/SKILL.md" || missing+="$t "; done
  check "agent $agent: setup grants every graph tool it lists" "" "$missing"
done
check "delegate skill: no codebase-memory left" false "$(grep -q 'codebase-memory' "$ROOT/skills/delegate/SKILL.md" && echo true || echo false)"
# The agents have no Bash tool, so the delegate skill carries the setup step, and only with the flags that keep it to the data folder.
check "delegate skill: names the contained setup command" true \
  "$(grep -q 'graphicle setup --clients none --no-hooks --no-capture --no-instructions' "$ROOT/skills/delegate/SKILL.md" && echo true || echo false)"
check "agents: first-line fallback names graphicle setup" 2 "$(grep -l 'the repository is probably not set up for Graphicle (`graphicle setup` does that)' "$ROOT"/agents/*.md | wc -l | tr -d ' ')"

# ruff.toml targets py314, which formats except (A, B) as except A, B. That is a
# syntax error before 3.14, so every hook must declare the matching floor.
for hook in "$ROOT"/hooks/*.py; do
  check "hook $(basename "$hook"): requires-python is >=3.14" true \
    "$(rg -q '^# requires-python = ">=3\.14"$' "$hook" && echo true || echo false)"
done

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
  # Ten is the house ceiling for an agent's tool list, counting MCP tools. Subagents
  # see every tool definition up front, so a longer list makes selection less reliable.
  tool_count=$(tr ',' '\n' <<<"$tools" | sed '/^ *$/d' | wc -l | tr -d ' ')
  check "agent $agent: at most ten tools" true "$([[ $tool_count -le 10 ]] && echo true || echo false)"
  check "agent $agent: sets maxTurns as a backstop" true \
    "$([[ "$fm" =~ (^|$'\n')maxTurns:\ [0-9]+ ]] && echo true || echo false)"
done

# --- whole plugin ------------------------------------------------------------
check "no ../ path out of the plugin" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' '\.\./' . || true)"
# tests/ is excluded because this file holds the pattern itself.
check "no em or en dash" "" "$(cd "$ROOT" && rg -n --glob '!tests/**' '[—–]' . || true)"
# The setup skill names the old bare files under ~/.claude/agents/ on purpose.
check "agents named only with the orchestration: prefix" "" \
  "$(rg -n -P '(?<!orchestration:)(?<![\w-])(repo-map|call-sites|api-docs)(?![\w-])' "$ROOT/skills" "$ROOT/hooks" --glob '!*.json' | grep -v '\.claude/agents/' || true)"
for script in "$SESSION_HOOK" "$HERE/acceptance.sh" "$HERE/prompt-probe.sh" "$HERE/stop-probe.sh"; do
  check "executable: ${script#"$ROOT"/}" true "$([[ -x "$script" ]] && echo true || echo false)"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
