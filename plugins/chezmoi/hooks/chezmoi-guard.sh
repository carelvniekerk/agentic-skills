#!/usr/bin/env bash
# PreToolUse: refuse to edit a chezmoi-managed destination file.
#
# Editing the working-tree copy appears to succeed and is then silently
# reverted by the next `chezmoi apply`. The edit belongs in the chezmoi source.
#
# Fails open throughout. A dotfile manager that is missing, uninitialised or
# broken must not make every file edit in every session fail.
set -uo pipefail

# 30 minutes. This hook fires on every single file edit, so the managed list is
# cached rather than re-derived from chezmoi each time.
readonly TTL=1800

tmp_dir=${TMPDIR:-/tmp}
tmp_dir=${tmp_dir%/}
readonly CACHE="$tmp_dir/chezmoi-guard-$UID.managed"
readonly SRC_CACHE="$tmp_dir/chezmoi-guard-$UID.source"

now() {
  # EPOCHSECONDS is a bash 5 builtin, so the common path forks nothing.
  if [[ -n ${EPOCHSECONDS:-} ]]; then
    printf '%s' "$EPOCHSECONDS"
  else
    date +%s
  fi
}

# Resolve symlinks in the directory chain and leave the leaf alone. `cd -P`
# plus `pwd -P` is POSIX, unlike GNU coreutils realpath, which macOS does not
# ship. On macOS this is what turns /tmp into /private/tmp.
resolve() {
  local path="$1" dir base resolved
  dir=${path%/*}
  base=${path##*/}
  [[ "$dir" == "$path" ]] && dir=.
  [[ -z "$dir" ]] && dir=/
  if resolved=$(cd -P -- "$dir" 2>/dev/null && pwd -P); then
    printf '%s/%s' "${resolved%/}" "$base"
  else
    # The directory does not exist yet, as when Write creates a new tree.
    # Fall back to the lexical path rather than guessing.
    printf '%s' "$path"
  fi
}

# Expand a leading ~ and make the path absolute against the tool call's cwd.
# No symlink resolution, so the caller can compare both spellings.
absolutise() {
  local path="$1" cwd="$2"
  case "$path" in
    '~') path="$HOME" ;;
    '~/'*) path="$HOME/${path#'~/'}" ;;
    /*) ;;
    *) [[ -n "$cwd" ]] && path="${cwd%/}/$path" ;;
  esac
  printf '%s' "$path"
}

# Rebuild both caches atomically. Returns non-zero if chezmoi cannot answer, in
# which case the caller allows the edit.
rebuild() {
  local scratch
  umask 077

  scratch=$(mktemp "$CACHE.XXXXXX") || return 1
  {
    now
    echo
    chezmoi managed --path-style absolute
  } >"$scratch" 2>/dev/null
  # Line 1 is the build timestamp, so a usable cache has at least two lines.
  if [[ $(wc -l <"$scratch") -lt 2 ]]; then
    rm -f "$scratch"
    return 1
  fi
  mv -f "$scratch" "$CACHE" || {
    rm -f "$scratch"
    return 1
  }

  scratch=$(mktemp "$SRC_CACHE.XXXXXX") || return 1
  if ! chezmoi source-path >"$scratch" 2>/dev/null || [[ ! -s "$scratch" ]]; then
    rm -f "$scratch"
    return 1
  fi
  # Resolve the source directory once here so the hot path never has to.
  resolve "$(<"$scratch")" >"$scratch.r" 2>/dev/null || {
    rm -f "$scratch" "$scratch.r"
    return 1
  }
  mv -f "$scratch.r" "$SRC_CACHE" || {
    rm -f "$scratch" "$scratch.r"
    return 1
  }
  rm -f "$scratch"
}

# One jq invocation for both fields, because this runs on every file edit.
{
  IFS= read -r file
  IFS= read -r cwd
} < <(jq -r '.tool_input.file_path // "", (.cwd // "")')
[[ -n "$file" ]] || exit 0

# No chezmoi means nothing is managed. Do not consult a stale cache.
command -v chezmoi >/dev/null 2>&1 || exit 0

built=
[[ -r "$CACHE" ]] && IFS= read -r built <"$CACHE"
if [[ ! "$built" =~ ^[0-9]+$ ]] || (($(now) - built >= TTL)) || [[ ! -s "$SRC_CACHE" ]]; then
  rebuild || exit 0
fi
[[ -s "$CACHE" && -s "$SRC_CACHE" ]] || exit 0

raw=$(absolutise "$file" "$cwd")
target=$(resolve "$raw")
IFS= read -r source_dir <"$SRC_CACHE"

# Editing inside the chezmoi source directory is the correct action, so it is
# allowed before any managed-set lookup.
for candidate in "$raw" "$target"; do
  case "$candidate" in
    "$source_dir" | "$source_dir"/*) exit 0 ;;
  esac
done

# Both spellings are checked because the managed list is emitted against
# chezmoi's own destination directory, which may or may not be symlink-resolved.
grep -qxF -e "$raw" -e "$target" "$CACHE" || exit 0

# Only now, on the rare deny path, is chezmoi worth spawning again.
src=$(chezmoi source-path -- "$target" 2>/dev/null) ||
  src=$(chezmoi source-path -- "$raw" 2>/dev/null) ||
  src=""

if [[ -n "$src" ]]; then
  reason="$target is managed by chezmoi, so editing it here would be reverted by the next \`chezmoi apply\`. Edit the source file $src instead, then run \`chezmoi apply\` to update the working copy."
else
  reason="$target is managed by chezmoi, so editing it here would be reverted by the next \`chezmoi apply\`. Run \`chezmoi source-path $target\` to find the source file, edit that instead, then run \`chezmoi apply\`."
fi

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
