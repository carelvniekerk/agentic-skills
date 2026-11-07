#!/usr/bin/env bash
# Shared helpers. Sourced by every hook in this directory.
# Written for bash 3.2, which is what macOS ships: no mapfile, no associative arrays.

# Resolve a project-local binary by walking up from the working directory to the
# filesystem root, so a monorepo package finds the tool installed at the
# workspace root. Prints the path and returns 1 when there is none.
#
# Never falls back to npx, npm exec or pnpm exec. npx prompts before it installs
# a missing package and can reach the network, which a hook must not do, and
# whether `--no-install` closes that gap was not confirmed in the npm docs.
find_bin() {
  local name="$1" dir="$PWD"
  while :; do
    if [[ -x "$dir/node_modules/.bin/$name" ]]; then
      printf '%s' "$dir/node_modules/.bin/$name"
      return 0
    fi
    [[ "$dir" == "/" ]] && return 1
    dir=$(dirname "$dir")
  done
}

# Print the first file with one of the given names, walking up from the working
# directory. Returns 1 when none exists.
find_up() {
  local dir="$PWD" name
  while :; do
    for name in "$@"; do
      if [[ -e "$dir/$name" ]]; then
        printf '%s' "$dir/$name"
        return 0
      fi
    done
    [[ "$dir" == "/" ]] && return 1
    dir=$(dirname "$dir")
  done
}

has_biome_config() {
  find_up biome.json biome.jsonc .biome.json .biome.jsonc >/dev/null
}

# ESLint 10 reads flat config only. A legacy .eslintrc is deliberately not
# detected, because ESLint 10 ignores it and exits 2 when no flat config exists.
has_eslint_config() {
  find_up eslint.config.js eslint.config.mjs eslint.config.cjs \
    eslint.config.ts eslint.config.mts eslint.config.cts >/dev/null
}

has_prettier_config() {
  local pkg
  find_up .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml \
    .prettierrc.json5 .prettierrc.js .prettierrc.ts .prettierrc.mjs \
    .prettierrc.mts .prettierrc.cjs .prettierrc.cts .prettierrc.toml \
    prettier.config.js prettier.config.ts prettier.config.mjs \
    prettier.config.mts prettier.config.cjs prettier.config.cts >/dev/null && return 0
  pkg=$(find_up package.json) || return 1
  jq -e 'has("prettier")' "$pkg" >/dev/null 2>&1
}

# Pick the lint and format toolchain, deferring to what the project configures.
# Biome wins when it is configured. ESLint and Prettier are used when the project
# configures either of them and Biome is absent. A project with no configuration
# at all gets Biome with its defaults, but only if Biome is installed.
# Prints "biome", "eslint-prettier" or nothing.
choose_toolchain() {
  if has_biome_config; then
    echo biome
  elif has_eslint_config || has_prettier_config; then
    echo eslint-prettier
  elif find_bin biome >/dev/null; then
    echo biome
  fi
}

# Print a path relative to the working directory when it lies below it, whether
# the directory is spelt logically or physically, and the path unchanged otherwise.
# Biome given an absolute path through a symlinked ancestor (/var is a link to
# /private/var on macOS) reports "Checked 0 files" and exits 0, so a hook that
# passes the absolute file_path from the tool event would skip the file silently.
relative_to_project() {
  local f="${1//\/\//\/}" base
  for base in "${PWD//\/\//\/}" "$(pwd -P)"; do
    if [[ "$f" == "$base/"* ]]; then
      printf '%s' "${f#"$base"/}"
      return 0
    fi
  done
  printf '%s' "$f"
}

# Print the directory of the nearest package.json at or above a file, relative to
# the working directory, or "." when the file has none below the project root.
# A MERN project usually has client/ and server/ packages with no package.json at
# the root, and each package carries its own tool configuration and tsconfig.json.
package_dir_of() {
  local rel dir
  rel=$(relative_to_project "$1")
  dir=$(dirname "$rel")
  while :; do
    if [[ -f "$dir/package.json" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    [[ "$dir" == "." || "$dir" == "/" ]] && break
    dir=$(dirname "$dir")
  done
  printf '.'
}

is_js_file() {
  case "$1" in
    */node_modules/*) return 1 ;;
    *.ts | *.tsx | *.mts | *.cts | *.js | *.jsx | *.mjs | *.cjs) [[ -f "$1" ]] ;;
    *) return 1 ;;
  esac
}

digest() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}

# A short stable key for the current project, used to name files kept outside the
# tree so two projects never share a TypeScript build cache.
project_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$PWD" | shasum | cut -c1-12
  else
    printf '%s' "$PWD" | sha256sum | cut -c1-12
  fi
}

# The marker that makes a write a secret. Matches the PEM armour line of an RSA,
# EC, DSA, OpenSSH, PGP or PKCS#8 private key.
readonly PRIVATE_KEY_PATTERN='-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----'
