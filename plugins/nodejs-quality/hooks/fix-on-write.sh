#!/usr/bin/env bash
# PostToolUse: fix JavaScript and TypeScript files silently, report nothing unless
# the copy on disk changed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

file=$(jq -r '.tool_input.file_path // empty' <<<"$(cat)")
is_js_file "$file" || exit 0

# Work from the package that owns the file, so its own configuration is found.
package=$(package_dir_of "$file")
target=$(relative_to_project "$file")
if [[ "$package" != "." ]]; then
  cd "$package" || exit 0
  target=${target#"$package"/}
fi

toolchain=$(choose_toolchain)
if [[ -z "$toolchain" ]]; then
  echo "fix-on-write: no Biome, ESLint or Prettier setup found, so $file was left as written." >&2
  exit 0
fi

before=$(digest "$file")

# The exit codes are ignored on purpose. Biome and ESLint exit 1 when a finding
# survives the safe fixes, which is not a failure of this hook. The Stop hook
# reports what is left.
case "$toolchain" in
  biome)
    biome=$(find_bin biome) || {
      echo "fix-on-write: Biome is configured but not installed in node_modules, so $file was left as written." >&2
      exit 0
    }
    # --no-errors-on-unmatched keeps a file that biome.json excludes from exiting 1.
    "$biome" check --write --colors=off --no-errors-on-unmatched "$target" >/dev/null 2>&1
    ;;
  eslint-prettier)
    # Lint fixes first, then format, so that a removed import cannot leave
    # unformatted blank lines behind for the next write to report.
    if has_eslint_config && eslint=$(find_bin eslint); then
      "$eslint" --fix --no-warn-ignored "$target" >/dev/null 2>&1
    fi
    if has_prettier_config && prettier=$(find_bin prettier); then
      "$prettier" --write --ignore-unknown "$target" >/dev/null 2>&1
    fi
    ;;
esac

after=$(digest "$file")
[[ "$before" == "$after" ]] && exit 0

jq -n --arg f "$file" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ($f + " was auto-fixed after this write (formatting and safe lint fixes). The copy on disk differs from what was just written, so re-read it before editing it again.")
  }
}'
