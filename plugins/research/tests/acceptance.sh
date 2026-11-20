#!/usr/bin/env bash
# Structure checks for the research plugin's copyedit step and its dependency.
# Whether the step actually runs is model behaviour and is not tested here.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd -P -- "$HERE/.." && pwd -P)
readonly ROOT
pass=0
fail=0

check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %-66s\n' "$1"
    ((pass++))
  else
    printf 'FAIL  %-66s expected %q, got %q\n' "$1" "$2" "$3"
    ((fail++))
  fi
}

check "manifest: depends on writing" '["writing"]' "$(jq -c '.dependencies' "$ROOT/.claude-plugin/plugin.json")"
check "marketplace: writing is listed" true \
  "$(jq -e '.plugins[] | select(.name == "writing")' "$ROOT/../../.claude-plugin/marketplace.json" >/dev/null && echo true || echo false)"
check "reference: copyedit-step.md exists" true "$([[ -f "$ROOT/references/copyedit-step.md" ]] && echo true || echo false)"

for skill in deep-research literature-review source-comparison paper-draft paper-code-audit; do
  f="$ROOT/skills/$skill/SKILL.md"
  check "$skill: reads the copyedit step" true \
    "$(grep -q 'references/copyedit-step.md' "$f" && echo true || echo false)"
  check "$skill: may call the Skill tool, and the step names writing:copyedit" true \
    "$(sed -n 's/^allowed-tools: *//p' "$f" | grep -qw 'Skill' && grep -q 'writing:copyedit' "$ROOT/references/copyedit-step.md" && echo true || echo false)"
  check "$skill: Copyedit comes before Deliver" true \
    "$(awk '/^## [0-9]+\. Copyedit/{c=NR} /^## [0-9]+\. Deliver/{d=NR} END{print (c > 0 && d > c) ? "true" : "false"}' "$f")"
  check "$skill: checklist ticks the copyedit" true \
    "$(grep -q '^- \[ \] [0-9]*\. Verified draft copyedited by writing:copyedit' "$f" && echo true || echo false)"
done
for skill in tldr eli5 external-research peer-review; do
  check "$skill: is not copyedited" false \
    "$(grep -q 'copyedit-step.md' "$ROOT/skills/$skill/SKILL.md" && echo true || echo false)"
done
check "no em or en dash in the step" "" "$(rg -n '[—–]' "$ROOT/references/copyedit-step.md" || true)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
