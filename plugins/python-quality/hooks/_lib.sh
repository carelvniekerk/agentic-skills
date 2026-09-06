#!/usr/bin/env bash
# Shared helpers. Sourced by every hook in this directory.

# Resolve a console script from PATH, falling back to uvx. $1 is the command,
# $2 the PyPI package that provides it. Returns 127 when neither the binary nor
# uvx is available, which callers must distinguish from a real check failure.
#
# type -P rather than command -v: command -v also resolves shell functions, and
# the ruff wrapper below is one, so the check would always succeed and then
# invoke a binary that is not there.
tool() {
  local cmd="$1" pkg="$2" path
  shift 2
  path=$(type -P "$cmd")
  if [[ -n "$path" ]]; then
    "$path" "$@"
  elif command -v uvx >/dev/null 2>&1; then
    uvx --from "$pkg" "$cmd" "$@"
  else
    return 127
  fi
}

# A pre-commit-hooks console script. Prefers a real install on PATH
# (uv tool install pre-commit-hooks), falls back to uvx.
pch() {
  local name="$1"
  shift
  tool "$name" pre-commit-hooks "$@"
}

# Shadows the ruff binary for every caller in this directory, so the uvx
# fallback applies to ruff on the same terms as the pre-commit-hooks scripts.
ruff() {
  tool ruff ruff "$@"
}

# Shadows the ty binary on the same terms as ruff.
ty() {
  tool ty ty "$@"
}

# Whether ruff can be run at all, by either route. Callers check this before
# doing work, because a missing ruff is a broken hook rather than a clean file.
ruff_available() {
  [[ -n "$(type -P ruff)" ]] || command -v uvx >/dev/null 2>&1
}

is_python_file() {
  case "$1" in
    *.py | *.pyi) [[ -f "$1" ]] ;;
    *) return 1 ;;
  esac
}

# Ask ruff whether it would look at this path at all, rather than keeping a
# second copy of the exclude list in bash. With force-exclude = true in
# pyproject.toml, an excluded path produces this warning on stderr and nothing
# else. String matching against ruff's output, so re-check after a ruff upgrade.
# Verified against ruff 0.16.6.
ruff_would_skip() {
  ruff check --force-exclude "$1" 2>&1 >/dev/null | grep -q "No Python files found"
}

digest() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}
