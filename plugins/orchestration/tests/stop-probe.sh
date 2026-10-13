#!/usr/bin/env bash
# Probe the Stop agent hook in real headless sessions. Billed: about four
# sessions, each with one or two hook calls. It reads the debug log for the
# hook's structured verdict, because the hook's reason never reaches stdout.
#
# The hook reads ~/.claude/CLAUDE.md, which a headless session may not read
# without a permission rule. Case D runs without the rule on purpose: it shows
# the style check failing open, which is the failure the setup skill prevents.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly PLUGIN="$HERE/.."
readonly ALLOW='{"permissions":{"allow":["Read(~/.claude/CLAUDE.md)"]}}'
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/stop-probe.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT

pass=0
fail=0

# probe <label> <settings-json> <expected first verdict> <reason must match, or ""> <prompt> [extra claude args...]
probe() {
  local label=$1 settings=$2 expect=$3 needle=$4 prompt=$5
  shift 5
  local dir="$SCRATCH/$label" log="$SCRATCH/$label.log"
  mkdir -p "$dir"
  # The prompt goes on stdin because --allowedTools is variadic and would swallow it as a tool name.
  (cd "$dir" && printf '%s' "$prompt" | claude -p --plugin-dir "$PLUGIN" --settings "$settings" --debug-file "$log" "$@" >/dev/null 2>&1)
  local first reason ok
  first=$(grep -m1 'Hooks: Got structured output: {"ok"' "$log" | sed 's/.*structured output: //')
  ok=$(jq -r '.ok' <<<"$first" 2>/dev/null || echo none)
  reason=$(jq -r '.reason // ""' <<<"$first" 2>/dev/null)
  if [[ "$ok" != "$expect" ]]; then
    printf 'FAIL  %-34s expected ok=%s, got %s\n        reason: %s\n' "$label" "$expect" "$ok" "$reason"
    ((fail++))
  elif [[ -n "$needle" ]] && ! grep -qi -E "$needle" <<<"$reason"; then
    printf 'FAIL  %-34s reason lacks /%s/\n        reason: %s\n' "$label" "$needle" "$reason"
    ((fail++))
  else
    printf 'ok    %-34s ok=%s  %s\n' "$label" "$ok" "${reason:0:110}"
    ((pass++))
  fi
}

probe "A-style-breach" "$ALLOW" false 'dash|semicolon' \
  'Reply with exactly this sentence and nothing else: The cache is warm — so reads are fast; writes are slow.'
probe "B-code-change-no-tests" "$ALLOW" false 'tests|checks' \
  'Create hello.py containing print("hi"). Do not mention tests or checks in your final message.' \
  --allowedTools Write
probe "C-clean-reply" "$ALLOW" true "" \
  'Reply with exactly this sentence and nothing else: The cache is warm, so reads are fast.'
# D passes when the hook says it could not read the file. The verdict is ok=true either way.
probe "D-no-read-rule-fails-open" '{}' true 'denied|could not|cannot|unable|not read' \
  'Reply with exactly this sentence and nothing else: The cache is warm — so reads are fast; writes are slow.'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
