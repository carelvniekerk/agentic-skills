#!/usr/bin/env bash
# Stop: block the turn until the Python files changed in it are clean.
# Repeats the checks rather than trusting the write hook, because PostToolUse
# only matches Edit, Write and NotebookEdit; shell-written files bypass it.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Stop takes no matcher, so this hook fires at the end of every turn in every
# project, Python or not. Deciding "nothing to check here" used to cost the
# whole git section below, and `git ls-files --others` walks the entire working
# tree: seconds in a repo carrying node_modules, datasets or checkpoints.
#
# Globs are expanded in-process, so this bails out before a single fork. Depth
# is capped at the project root and its immediate subdirectories, which is
# where a Python project always announces itself.
is_python_project() {
  local entry
  [[ -f pyproject.toml || -f requirements.txt ]] && return 0
  for entry in *.py *.pyi */*.py */*.pyi; do
    [[ -e "$entry" ]] && return 0
  done
  return 1
}
is_python_project || exit 0

input=$(cat)
session=$(jq -r '.session_id // "nosession"' <<<"$input" 2>/dev/null || echo nosession)

# A missing ruff is a broken hook, not a clean tree. Say so rather than letting
# every turn pass silently.
if ! ruff_available; then
  echo "quality gate: ruff is not reachable (not on PATH, no uvx), so nothing was checked." >&2
  exit 0
fi

# Collected with a read loop rather than mapfile, which needs bash 4 and is
# absent from the bash 3.2 that ships with macOS.
candidates=()
collect() { while IFS= read -r line; do [[ -n "$line" ]] && candidates+=("$line"); done; }

if git rev-parse --git-dir >/dev/null 2>&1; then
  collect < <(
    {
      # A repository with no commits yet has no HEAD to diff against.
      if git rev-parse --verify -q HEAD >/dev/null; then
        git diff --name-only --diff-filter=ACM HEAD -- '*.py' '*.pyi'
      fi
      git ls-files --others --exclude-standard -- '*.py' '*.pyi'
    } | sort -u
  )
else
  collect < <(find . -path ./.git -prune -o \( -name '*.py' -o -name '*.pyi' \) -print | sed 's|^\./||' | sort -u)
fi

files=()
for f in ${candidates[@]+"${candidates[@]}"}; do
  is_python_file "$f" || continue
  ruff_would_skip "$f" && continue
  files+=("$f")
done
(( ${#files[@]} )) || exit 0

# Bound the block/retry loop so a violation Claude cannot satisfy does not
# ping-pong forever. Kept outside the project tree so the counter never shows
# up in git status or gets committed.
attempts_file="${TMPDIR:-/tmp}/claude-turn-gate.${session}.attempts"
attempts=$(cat "$attempts_file" 2>/dev/null || echo 0)
[[ "$attempts" =~ ^[0-9]+$ ]] || attempts=0
if (( attempts >= 2 )); then
  rm -f "$attempts_file"
  echo "quality gate: still failing after $attempts attempts, letting the turn end." >&2
  exit 0
fi

report=""
add() { [[ -n "$2" ]] && report="${report}${1}:"$'\n'"${2}"$'\n\n'; }

# Diagnostics come back on stdout; stderr is kept separate so uvx's own warnings
# on the fallback path cannot land in the report as phantom findings.
stderr_file=$(mktemp "${TMPDIR:-/tmp}/turn-gate.XXXXXX")
trap 'rm -f "$stderr_file"' EXIT

# All four checkers share one convention: 0 is clean, 1 is findings, anything
# else means the tool could not run. A tool that could not run is reported to
# the user on stderr and contributes nothing, rather than blocking the turn or
# suppressing the checks that did run.
run_check() {
  local label="$1" out rc
  shift
  out=$("$@" 2>"$stderr_file"); rc=$?
  case $rc in
    0) ;;
    1) add "$label" "$out" ;;
    127) echo "quality gate: the $label check was skipped, its tool is not reachable." >&2 ;;
    *) printf 'quality gate: the %s check could not run:\n%s\n%s\n' "$label" "$out" "$(cat "$stderr_file")" >&2 ;;
  esac
}

# Nothing is overridden on any of these. pyproject.toml decides the rules.
run_check "ruff" ruff check --output-format concise "${files[@]}"
run_check "types" ty check --output-format concise "${files[@]}"
run_check "docstring position" pch check-docstring-first "${files[@]}"
run_check "private keys" pch detect-private-key "${files[@]}"

if [[ -z "$report" ]]; then
  rm -f "$attempts_file"
  exit 0
fi

echo $(( attempts + 1 )) > "$attempts_file"

jq -n --arg r "The quality gate failed on Python files changed this turn. Auto-fixable problems were already repaired at write time, so anything below either needs a real decision or came from a file written by a shell command, which bypasses the write hook:

$report" '{decision: "block", reason: $r}'
