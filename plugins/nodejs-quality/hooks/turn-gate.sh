#!/usr/bin/env bash
# Stop: block the turn until the JavaScript and TypeScript files changed in it are clean.
# Repeats the checks rather than trusting the write hook, because PostToolUse only
# matches Edit, Write and NotebookEdit and shell-written files bypass it.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
root=$PWD

# Stop takes no matcher, so this hook fires at the end of every turn in every
# project. Globs are expanded in-process, so a project that is not a Node project
# exits before a single fork, and before `git ls-files --others` can walk a large
# working tree. A MERN project has client/ and server/ packages and often no
# package.json at the root, so packages one and two levels down count.
is_node_project() {
  local entry
  [[ -f package.json ]] && return 0
  for entry in */package.json */*/package.json; do
    [[ -e "$entry" ]] && return 0
  done
  return 1
}
is_node_project || exit 0

input=$(cat)
session=$(jq -r '.session_id // "nosession"' <<<"$input" 2>/dev/null || echo nosession)

# Collected with a read loop rather than mapfile, which needs bash 4.
candidates=()
collect() { while IFS= read -r line; do [[ -n "$line" ]] && candidates+=("$line"); done; }

globs=('*.ts' '*.tsx' '*.mts' '*.cts' '*.js' '*.jsx' '*.mjs' '*.cjs')
if git rev-parse --git-dir >/dev/null 2>&1; then
  collect < <(
    {
      # A repository with no commits yet has no HEAD to diff against.
      if git rev-parse --verify -q HEAD >/dev/null; then
        # --relative limits the list to the project directory and prints paths
        # relative to it, which differ from repository paths in a subdirectory.
        git diff --name-only --relative --diff-filter=ACM HEAD -- "${globs[@]}"
      fi
      git ls-files --others --exclude-standard -- "${globs[@]}"
    } | sort -u
  )
else
  collect < <(
    find . \( -path ./.git -o -path '*/node_modules' \) -prune -o -type f \
      \( -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
      -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -print \
      | sed 's|^\./||' | sort -u
  )
fi

files=()
for f in ${candidates[@]+"${candidates[@]}"}; do
  is_js_file "$f" && files+=("$f")
done
(( ${#files[@]} )) || exit 0

# Bound the block and retry loop so a violation Claude cannot satisfy does not
# ping-pong forever. This replaces a stop_hook_active check, because the point of
# the second pass is to verify the fix. Kept outside the project tree so the
# counter never shows up in git status.
attempts_file="${TMPDIR:-/tmp}/claude-nodejs-turn-gate.${session}.attempts"
attempts=$(cat "$attempts_file" 2>/dev/null || echo 0)
[[ "$attempts" =~ ^[0-9]+$ ]] || attempts=0
if (( attempts >= 2 )); then
  rm -f "$attempts_file"
  echo "quality gate: still failing after $attempts attempts, letting the turn end." >&2
  exit 0
fi

report=""
add() { [[ -n "$2" ]] && report="${report}${1}:"$'\n'"${2}"$'\n\n'; }

# Output is capped so one noisy check cannot flood the block message.
cap() { head -n 60; }

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/nodejs-turn-gate.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

# Run a checker and sort its result into findings, tool failure or clean.
# Arguments: label, then the command.
# Biome and TypeScript exit 1 both for findings and for a broken configuration,
# so a configuration error is recognised by the marker text in the output and
# reported as a tool failure. A tool that could not run is reported on stderr and
# contributes nothing, rather than blocking the turn or hiding the other checks.
run_check() {
  local label="$1" out rc
  shift
  out=$("$@" 2>"$tmp_dir/stderr"); rc=$?
  out="$out$(cat "$tmp_dir/stderr")"
  case $rc in
    0) ;;
    1)
      if [[ "$out" == *"configuration resulted in errors"* ]]; then
        printf 'quality gate: the %s configuration is broken, so the check could not run:\n%s\n' "$label" "$(cap <<<"$out")" >&2
      else
        add "$label" "$(cap <<<"$out")"
      fi
      ;;
    *) printf 'quality gate: the %s check could not run (exit %s):\n%s\n' "$label" "$rc" "$(cap <<<"$out")" >&2 ;;
  esac
}

# Check the files of one package from inside that package, so that its own tool
# configuration, node_modules and tsconfig.json apply, and its paths stay short.
# Arguments: the package directory relative to the project root, then the files
# relative to the project root.
check_package() {
  local pkg="$1" suffix="" f toolchain biome eslint prettier tsc tsc_out tsc_rc mine others
  local rel=() typed=0
  shift
  [[ "$pkg" != "." ]] && suffix=" ($pkg)"
  for f in "$@"; do
    if [[ "$pkg" == "." ]]; then rel+=("$f"); else rel+=("${f#"$pkg"/}"); fi
    case "$f" in *.ts | *.tsx | *.mts | *.cts) typed=1 ;; esac
  done
  cd "$root/$pkg" || return 0

  toolchain=$(choose_toolchain)
  case "$toolchain" in
    biome)
      if biome=$(find_bin biome); then
        run_check "biome$suffix" "$biome" check --colors=off --no-errors-on-unmatched "${rel[@]}"
      else
        echo "quality gate: Biome is configured for ${pkg} but not installed in node_modules, so lint and format were not checked." >&2
      fi
      ;;
    eslint-prettier)
      if has_eslint_config; then
        if eslint=$(find_bin eslint); then
          run_check "eslint$suffix" "$eslint" --no-warn-ignored "${rel[@]}"
        else
          echo "quality gate: ESLint is configured for ${pkg} but not installed in node_modules, so it was not run." >&2
        fi
      fi
      if has_prettier_config; then
        if prettier=$(find_bin prettier); then
          run_check "prettier$suffix" "$prettier" --check --ignore-unknown "${rel[@]}"
        else
          echo "quality gate: Prettier is configured for ${pkg} but not installed in node_modules, so it was not run." >&2
        fi
      fi
      ;;
    *)
      echo "quality gate: no Biome, ESLint or Prettier setup found for ${pkg}, so lint and format were not checked." >&2
      ;;
  esac

  # Type check. TypeScript 7 refuses file arguments when a tsconfig.json is present
  # (TS5112), so the whole package is checked and the diagnostics are filtered to
  # the files changed this turn. Errors in other files are mentioned on stderr and
  # do not block, so an old backlog cannot hold up unrelated work. The build cache
  # lives outside the tree, keyed by the package directory.
  if [[ -f tsconfig.json ]]; then
    if tsc=$(find_bin tsc); then
      printf '%s\n' "${rel[@]}" >"$tmp_dir/changed"
      tsc_out=$("$tsc" -p . --noEmit --pretty false --noErrorTruncation \
        --incremental --tsBuildInfoFile "${TMPDIR:-/tmp}/claude-nodejs-tsc.$(project_key).tsbuildinfo" \
        2>"$tmp_dir/tsc_err"); tsc_rc=$?
      tsc_out="$tsc_out$(cat "$tmp_dir/tsc_err")"
      if (( tsc_rc == 0 )); then
        :
      elif grep -q -E 'error TS5[0-9]{3}:' <<<"$tsc_out"; then
        printf 'quality gate: tsconfig.json in %s has a problem, so the type check could not run:\n%s\n' "$pkg" "$(cap <<<"$tsc_out")" >&2
      else
        # A diagnostic starts at column 0 with the path. Indented lines continue the
        # previous diagnostic, so they follow it into or out of the report.
        mine=$(awk '
          NR == FNR { changed[$0] = 1; next }
          /^[^ \t]/ {
            keep = 0
            paren = index($0, "(")
            if (paren > 0 && (substr($0, 1, paren - 1) in changed)) keep = 1
          }
          keep { print }
        ' "$tmp_dir/changed" - <<<"$tsc_out")
        if [[ -n "$mine" ]]; then
          add "types$suffix" "$(cap <<<"$mine")"
        else
          others=$(grep -c -E '^[^ \t].*: error TS[0-9]+:' <<<"$tsc_out")
          echo "quality gate: tsc reports $others error(s) in $pkg, none in the files changed this turn, so the turn is not blocked." >&2
        fi
      fi
    else
      echo "quality gate: tsconfig.json exists in $pkg but tsc is not installed in node_modules, so types were not checked." >&2
    fi
  elif (( typed )); then
    echo "quality gate: TypeScript files changed but $pkg has no tsconfig.json, so types were not checked." >&2
  fi

  cd "$root" || return 0
}

# Group the changed files by the package that owns them. Sorting the pairs puts
# each package's files together without an associative array, which bash 3.2 lacks.
pairs=()
for f in "${files[@]}"; do
  pairs+=("$(package_dir_of "$f")"$'\t'"$f")
done
current=""
group=()
while IFS=$'\t' read -r pkg file; do
  if [[ -n "$current" && "$pkg" != "$current" ]]; then
    check_package "$current" "${group[@]}"
    group=()
  fi
  current="$pkg"
  group+=("$file")
done < <(printf '%s\n' "${pairs[@]}" | sort)
[[ -n "$current" ]] && check_package "$current" "${group[@]}"

# A second line of defence behind secrets-guard, for files written by a shell command.
keys=$(grep -l -E -e "$PRIVATE_KEY_PATTERN" "${files[@]}" 2>/dev/null)
add "private keys" "$keys"

if [[ -z "$report" ]]; then
  rm -f "$attempts_file"
  exit 0
fi

echo $(( attempts + 1 )) > "$attempts_file"

jq -n --arg r "The quality gate failed on JavaScript or TypeScript files changed this turn. Auto-fixable problems were already repaired at write time, so anything below either needs a real decision or came from a file written by a shell command, which bypasses the write hook:

$report" '{decision: "block", reason: $r}'
