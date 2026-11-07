#!/usr/bin/env bash
# Acceptance tests for the nodejs-quality hooks.
# Each case feeds a hook the event it receives in a session and checks the
# decision. Tools are stubs in a fixture node_modules/.bin, so the tests pin the
# routing and the exit-code handling of the hooks and need neither network nor
# an installed toolchain. A final section runs the real Biome when one is on PATH.
set -uo pipefail

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly HOOKS="$HERE/../hooks"
readonly GUARD="$HOOKS/secrets-guard.sh"
readonly FIXER="$HOOKS/fix-on-write.sh"
readonly GATE="$HOOKS/turn-gate.sh"

pass=0
fail=0
WORK=$(mktemp -d "${TMPDIR:-/tmp}/nodejs-quality-acc.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
# Keeps the attempt counters and the tsc cache of the gate inside the fixture.
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"

ok() { printf 'ok    %s\n' "$1"; ((pass++)); }
bad() { printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; ((fail++)); }

# check <label> <expected> <actual>
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "expected '$2', got '$3'"; fi
}

# check_has <label> <haystack> <needle>
check_has() {
  if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1" "output lacks '$3': $2"; fi
}

# check_lacks <label> <haystack> <needle>
check_lacks() {
  if [[ "$2" != *"$3"* ]]; then ok "$1"; else bad "$1" "output contains '$3'"; fi
}

# Build the PEM line at run time so that this file holds no complete marker.
PEM=$(printf -- '-----BEGIN %s PRIVATE KEY-----' RSA)
OPENSSH_PEM=$(printf -- '-----BEGIN %s PRIVATE KEY-----' OPENSSH)

# ---------------------------------------------------------------- secrets-guard

guard_event() {
  jq -nc --arg tool "$1" --arg file "$2" --arg key "$3" --arg text "$4" \
    '{hook_event_name:"PreToolUse", tool_name:$tool, tool_input:({file_path:$file} + {($key):$text})}'
}

guard() {
  local out rc
  out=$(printf '%s' "$1" | "$GUARD" 2>/dev/null); rc=$?
  ((rc != 0)) && { printf 'error:%s' "$rc"; return; }
  [[ -z "$out" ]] && { printf 'allow'; return; }
  jq -r '.hookSpecificOutput.permissionDecision // "malformed"' <<<"$out"
}

echo "== secrets-guard"
check "Write of a key into a .ts file is denied" deny "$(guard "$(guard_event Write /p/a.ts content "const k = \`$PEM\`")")"
check "Write of a key into a .tsx file is denied" deny "$(guard "$(guard_event Write /p/a.tsx content "$PEM")")"
check "Edit of a key into a .js file is denied" deny "$(guard "$(guard_event Edit /p/a.js new_string "$PEM")")"
check "Write of a key into a .mjs file is denied" deny "$(guard "$(guard_event Write /p/a.mjs content "$PEM")")"
check "Write of a key into a .cjs file is denied" deny "$(guard "$(guard_event Write /p/a.cjs content "$PEM")")"
check "OpenSSH key header is denied" deny "$(guard "$(guard_event Write /p/a.ts content "$OPENSSH_PEM")")"
check "Write without a key is allowed" allow "$(guard "$(guard_event Write /p/a.ts content 'export const x = 1;')")"
check "A public key block is allowed" allow "$(guard "$(guard_event Write /p/a.ts content '-----BEGIN PUBLIC KEY-----')")"
check "A key in a .py file is left to python-quality" allow "$(guard "$(guard_event Write /p/a.py content "$PEM")")"
check "A key in a .md file is out of scope" allow "$(guard "$(guard_event Write /p/a.md content "$PEM")")"
check "Empty content is allowed" allow "$(guard "$(guard_event Write /p/a.ts content '')")"
check "Event without a file path is allowed" allow "$(guard '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{}}')"
reason=$(printf '%s' "$(guard_event Write /p/a.ts content "$PEM")" | "$GUARD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason')
check_has "Denial reason names the file" "$reason" "/p/a.ts"

# ------------------------------------------------------------------- fixtures

# A git repository with one commit and a package.json. Prints its path.
new_project() {
  local dir
  dir=$(mktemp -d "$WORK/proj.XXXXXX")
  (
    cd "$dir" || exit 1
    git init -q
    git config user.email test@example.com
    git config user.name Test
    printf '{ "name": "fixture" }\n' >package.json
    printf 'node_modules\n' >.gitignore
    git add -A
    git commit -q -m init
  )
  printf '%s' "$dir"
}

# stub <project> <tool> <exit code> <stdout text>
stub() {
  local path="$1/node_modules/.bin/$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\nexit %s\n' "$4" "$3" >"$path"
  chmod +x "$path"
}

# A stub that edits its last argument, as a formatter does, and exits 1 like Biome.
fixer_stub() {
  local path="$1/node_modules/.bin/$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\nfor a; do last="$a"; done\necho "// fixed" >>"$last"\nexit 1\n' >"$path"
  chmod +x "$path"
}

# run_hook <hook> <project> <event json>; sets OUT, ERR and RC.
run_hook() {
  OUT=$(printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" "$1" 2>"$WORK/err"); RC=$?
  ERR=$(cat "$WORK/err")
}

# ----------------------------------------------------------------- fix-on-write

edit_event() { jq -nc --arg f "$1" '{hook_event_name:"PostToolUse", tool_name:"Edit", tool_input:{file_path:$f}}'; }

echo "== fix-on-write"
P=$(new_project)
printf '{}\n' >"$P/biome.json"
fixer_stub "$P" biome
printf 'const a = 1\n' >"$P/a.ts"
run_hook "$FIXER" "$P" "$(edit_event "$P/a.ts")"
check_has "Biome configured and file changed: reports the auto-fix" "$OUT" "was auto-fixed"
check "Reported through additionalContext" PostToolUse "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$OUT")"

stub "$P" biome 0 ""
printf 'const a = 1;\n' >"$P/b.ts"
run_hook "$FIXER" "$P" "$(edit_event "$P/b.ts")"
check "File unchanged by the tool: silent" "" "$OUT"

printf 'x\n' >"$P/notes.md"
fixer_stub "$P" biome
run_hook "$FIXER" "$P" "$(edit_event "$P/notes.md")"
check "Markdown file is ignored" "" "$OUT"
check "Markdown file was not touched" "x" "$(cat "$P/notes.md")"

mkdir -p "$P/node_modules/pkg"
printf 'var x\n' >"$P/node_modules/pkg/i.js"
run_hook "$FIXER" "$P" "$(edit_event "$P/node_modules/pkg/i.js")"
check "File under node_modules is ignored" "" "$OUT"

rm -f "$P/node_modules/.bin/biome"
run_hook "$FIXER" "$P" "$(edit_event "$P/a.ts")"
check "Biome configured but not installed: silent on stdout" "" "$OUT"
check_has "Biome not installed: says so on stderr" "$ERR" "not installed"

P2=$(new_project)
printf 'const a = 1\n' >"$P2/a.ts"
run_hook "$FIXER" "$P2" "$(edit_event "$P2/a.ts")"
check "No toolchain at all: silent on stdout" "" "$OUT"
check_has "No toolchain: says so on stderr" "$ERR" "no Biome, ESLint or Prettier"

P3=$(new_project)
printf '{}\n' >"$P3/.prettierrc"
fixer_stub "$P3" prettier
printf 'const a = 1\n' >"$P3/a.ts"
run_hook "$FIXER" "$P3" "$(edit_event "$P3/a.ts")"
check_has "Prettier configured and Biome absent: Prettier runs" "$OUT" "was auto-fixed"

P4=$(new_project)
printf '{}\n' >"$P4/biome.json"
printf '{}\n' >"$P4/.prettierrc"
fixer_stub "$P4" biome
fixer_stub "$P4" prettier
printf 'const a = 1\n' >"$P4/a.ts"
run_hook "$FIXER" "$P4" "$(edit_event "$P4/a.ts")"
check "Biome and Prettier both configured: Biome wins, one fix" "1" "$(grep -c 'fixed' "$P4/a.ts")"

P5=$(new_project)
printf '{ "name": "f", "prettier": { "semi": false } }\n' >"$P5/package.json"
fixer_stub "$P5" prettier
printf 'const a = 1\n' >"$P5/a.ts"
run_hook "$FIXER" "$P5" "$(edit_event "$P5/a.ts")"
check_has "Prettier key in package.json counts as configuration" "$OUT" "was auto-fixed"

# ------------------------------------------------------------------- turn-gate

stop_event() { jq -nc --arg s "$1" '{hook_event_name:"Stop", session_id:$s, stop_hook_active:false}'; }

echo "== turn-gate"
NONNODE=$(mktemp -d "$WORK/plain.XXXXXX")
printf 'x = 1\n' >"$NONNODE/a.py"
printf 'const a = 1;\n' >"$NONNODE/stray.ts"
run_hook "$GATE" "$NONNODE" "$(stop_event s0)"
check "Not a Node project (no package.json): silent" "" "$OUT"
check "Not a Node project: nothing on stderr" "" "$ERR"

G=$(new_project)
printf '{}\n' >"$G/biome.json"
stub "$G" biome 1 "src/a.ts:1:1 lint/suspicious/noDoubleEquals  Using == is unsafe"
run_hook "$GATE" "$G" "$(stop_event s1)"
check "Node project with no JavaScript changes: silent" "" "$OUT"

mkdir -p "$G/src"
printf 'if (a == b) {}\n' >"$G/src/a.ts"
run_hook "$GATE" "$G" "$(stop_event s2)"
check "Untracked .ts file with a Biome finding: blocked" block "$(jq -r '.decision' <<<"$OUT")"
check_has "Block reason carries the finding" "$OUT" "noDoubleEquals"
check_has "Block reason names the check" "$OUT" "biome:"
run_hook "$GATE" "$G" "$(stop_event s2)"
check "Second attempt in the same session: blocked again" block "$(jq -r '.decision' <<<"$OUT")"
run_hook "$GATE" "$G" "$(stop_event s2)"
check "Third attempt: the turn is let through" "" "$OUT"
check_has "Third attempt: says why on stderr" "$ERR" "still failing after 2 attempts"

stub "$G" biome 0 ""
run_hook "$GATE" "$G" "$(stop_event s3)"
check "Clean Biome run: silent" "" "$OUT"

stub "$G" biome 1 "Biome exited because the configuration resulted in errors. Please fix them."
run_hook "$GATE" "$G" "$(stop_event s4)"
check "Biome configuration error: not treated as a finding" "" "$OUT"
check_has "Biome configuration error: reported on stderr" "$ERR" "configuration is broken"

stub "$G" biome 2 "internal error"
run_hook "$GATE" "$G" "$(stop_event s5)"
check "Biome exit 2: not treated as a finding" "" "$OUT"
check_has "Biome exit 2: reported as could not run" "$ERR" "could not run"

rm -f "$G/node_modules/.bin/biome"
run_hook "$GATE" "$G" "$(stop_event s6)"
check "Biome configured but not installed: not blocked" "" "$OUT"
check_has "Biome not installed: says so on stderr" "$ERR" "not installed"

printf 'tracked\n' >"$G/src/b.ts"
git -C "$G" add src/b.ts
git -C "$G" commit -q -m "add b"
printf 'changed\n' >"$G/src/b.ts"
stub "$G" biome 1 "src/b.ts finding"
run_hook "$GATE" "$G" "$(stop_event s7)"
check_has "Modified tracked file is checked" "$OUT" "src/b.ts finding"

# Files are passed to the tool as arguments; an unchanged tracked file is not.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@"\nexit 1\n' >"$G/node_modules/.bin/biome"
git -C "$G" add -A
git -C "$G" commit -q -m "all"
printf 'again\n' >"$G/src/b.ts"
run_hook "$GATE" "$G" "$(stop_event s8)"
check_has "Changed file is passed to the tool" "$OUT" "src/b.ts"
check_lacks "Unchanged file is not passed to the tool" "$OUT" "src/a.ts"

echo "== turn-gate: ESLint and Prettier"
E=$(new_project)
printf 'export default [];\n' >"$E/eslint.config.js"
printf '{}\n' >"$E/.prettierrc"
mkdir -p "$E/src"
printf 'var a\n' >"$E/src/a.js"
stub "$E" eslint 1 "src/a.js  1:1  error  Unexpected var  no-var"
stub "$E" prettier 1 "[warn] src/a.js"
run_hook "$GATE" "$E" "$(stop_event e1)"
check_has "ESLint finding blocks" "$OUT" "no-var"
check_has "Prettier finding blocks" "$OUT" "[warn] src/a.js"

stub "$E" eslint 2 "Oops! Something went wrong!"
stub "$E" prettier 0 ""
run_hook "$GATE" "$E" "$(stop_event e2)"
check "ESLint exit 2 (config error): not treated as a finding" "" "$OUT"
check_has "ESLint exit 2: reported on stderr" "$ERR" "could not run"

echo "== turn-gate: types"
T=$(new_project)
printf '{}\n' >"$T/biome.json"
printf '{}\n' >"$T/tsconfig.json"
stub "$T" biome 0 ""
mkdir -p "$T/src"
printf 'export const n = 1;\n' >"$T/src/a.ts"
stub "$T" tsc 0 ""
run_hook "$GATE" "$T" "$(stop_event t1)"
check "Clean tsc run: silent" "" "$OUT"

stub "$T" tsc 1 "src/a.ts(1,14): error TS2322: Type 'string' is not assignable to type 'number'."
run_hook "$GATE" "$T" "$(stop_event t2)"
check "Type error in a changed file: blocked" block "$(jq -r '.decision' <<<"$OUT")"
check_has "Type error: reported under types" "$OUT" "types:"
check_has "Type error: diagnostic is in the reason" "$OUT" "TS2322"

stub "$T" tsc 1 "src/other.ts(3,1): error TS2304: Cannot find name 'x'."
run_hook "$GATE" "$T" "$(stop_event t3)"
check "Type error only in an unchanged file: not blocked" "" "$OUT"
check_has "Type error elsewhere: counted on stderr" "$ERR" "none in the files changed this turn"

stub "$T" tsc 1 "tsconfig.json(1,24): error TS5023: Unknown compiler option 'nopeOption'."
run_hook "$GATE" "$T" "$(stop_event t4)"
check "tsconfig problem: not treated as a finding" "" "$OUT"
check_has "tsconfig problem: reported on stderr" "$ERR" "has a problem"

rm -f "$T/node_modules/.bin/tsc"
run_hook "$GATE" "$T" "$(stop_event t5)"
check "tsconfig present but tsc missing: not blocked" "" "$OUT"
check_has "tsc missing: says so on stderr" "$ERR" "tsc is not installed"

rm -f "$T/tsconfig.json"
stub "$T" tsc 1 "src/a.ts(1,1): error TS2322: x"
run_hook "$GATE" "$T" "$(stop_event t6)"
check "No tsconfig.json: type check is skipped" "" "$OUT"

# A diagnostic that wraps onto indented lines stays with its file.
printf '{}\n' >"$T/tsconfig.json"
printf '#!/usr/bin/env bash\nprintf "src/a.ts(2,1): error TS2345: Argument is not assignable.\\n  Type A is not B.\\nsrc/z.ts(1,1): error TS1: elsewhere\\n  detail of z\\n"\nexit 1\n' >"$T/node_modules/.bin/tsc"
chmod +x "$T/node_modules/.bin/tsc"
run_hook "$GATE" "$T" "$(stop_event t7)"
check_has "Continuation line of a changed file is kept" "$OUT" "Type A is not B."
check_lacks "Diagnostic of an unchanged file is dropped" "$OUT" "elsewhere"
check_lacks "Continuation line of an unchanged file is dropped" "$OUT" "detail of z"

echo "== MERN layout: client/ and server/ packages, nothing at the root"
M=$(mktemp -d "$WORK/mern.XXXXXX")
(
  cd "$M" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name Test
  mkdir -p server/src client/src
  printf '{ "name": "server" }\n' >server/package.json
  printf '{ "name": "client" }\n' >client/package.json
  printf 'node_modules\n' >.gitignore
  printf '{}\n' >server/biome.json
  printf '{}\n' >server/tsconfig.json
  printf '{}\n' >client/biome.json
  git add -A
  git commit -q -m init
)
stub "$M/server" biome 1 "src/a.ts:1:1 lint/suspicious/noDoubleEquals  Using == is unsafe"
stub "$M/server" tsc 0 ""
stub "$M/client" biome 0 ""
printf 'if (a == b) {}\n' >"$M/server/src/a.ts"
printf 'const c = 1;\n' >"$M/client/src/c.ts"
run_hook "$GATE" "$M" "$(stop_event m1)"
check "Finding in server/ blocks although the root has no package.json" block "$(jq -r '.decision' <<<"$OUT")"
check_has "The reason names the package" "$OUT" "(server)"
check_has "The reason carries the finding" "$OUT" "noDoubleEquals"
check_lacks "The clean client/ package adds nothing" "$OUT" "(client)"

stub "$M/server" biome 0 ""
stub "$M/server" tsc 1 "src/a.ts(1,14): error TS2322: Type 'string' is not assignable to type 'number'."
run_hook "$GATE" "$M" "$(stop_event m2)"
check "Type error in server/ blocks, with paths relative to the package" block "$(jq -r '.decision' <<<"$OUT")"
check_has "The type error is reported under the package" "$OUT" "types (server):"

stub "$M/server" tsc 0 ""
printf 'export const k: number = 1;\n' >"$M/client/src/d.ts"
run_hook "$GATE" "$M" "$(stop_event m3)"
check "A changed .ts file in a package without tsconfig.json is not blocked" "" "$OUT"
check_has "A package without tsconfig.json is reported on stderr" "$ERR" "client has no tsconfig.json"

# Tools are found by walking up, so a workspace root install serves a package.
printf '#!/usr/bin/env bash\nprintf "root biome: %%s\\n" "$@"\nexit 1\n' >"$WORK/rootbiome"
mkdir -p "$M/node_modules/.bin"
cp "$WORK/rootbiome" "$M/node_modules/.bin/biome"
chmod +x "$M/node_modules/.bin/biome"
rm -f "$M/client/node_modules/.bin/biome"
printf 'const e = 1;\n' >"$M/client/src/e.ts"
run_hook "$GATE" "$M" "$(stop_event m4)"
check_has "A hoisted root install serves the package" "$OUT" "root biome: src/e.ts"

# fix-on-write works from the package that owns the file.
rm -f "$M/node_modules/.bin/biome"
fixer_stub "$M/server" biome
printf 'let z = 1\n' >"$M/server/src/z.ts"
run_hook "$FIXER" "$M" "$(edit_event "$M/server/src/z.ts")"
check_has "fix-on-write repairs a file in a sub-package" "$OUT" "was auto-fixed"

echo "== turn-gate: private keys"
K=$(new_project)
printf '{}\n' >"$K/biome.json"
stub "$K" biome 0 ""
printf 'const k = `%s`;\n' "$PEM" >"$K/k.ts"
run_hook "$GATE" "$K" "$(stop_event k1)"
check_has "Private key written by a shell command is caught" "$OUT" "private keys:"
check_has "The file is named" "$OUT" "k.ts"

echo "== plugin wiring"
JSON="$HOOKS/hooks.json"
check "hooks.json is valid JSON" true "$(jq -e . "$JSON" >/dev/null 2>&1 && echo true || echo false)"
check "PreToolUse runs secrets-guard" '${CLAUDE_PLUGIN_ROOT}/hooks/secrets-guard.sh' "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$JSON")"
check "PostToolUse runs fix-on-write" '${CLAUDE_PLUGIN_ROOT}/hooks/fix-on-write.sh' "$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$JSON")"
check "Stop runs turn-gate" '${CLAUDE_PLUGIN_ROOT}/hooks/turn-gate.sh' "$(jq -r '.hooks.Stop[0].hooks[0].command' "$JSON")"
check "Write hooks match Edit, Write and NotebookEdit" 'Edit|Write|NotebookEdit' "$(jq -r '.hooks.PreToolUse[0].matcher' "$JSON")"
for f in secrets-guard.sh fix-on-write.sh turn-gate.sh _lib.sh; do
  check "$f is executable" true "$([[ -x "$HOOKS/$f" ]] && echo true || echo false)"
done
# Comments may name npx to explain why it is avoided, so only code lines count.
check "Scripts never call npx" 0 "$(grep -h -v -E '^[[:space:]]*#' "$HOOKS"/*.sh | grep -c -E '(^|[^a-z.])npx( |$)')"

# ------------------------------------------------------------- real Biome smoke

echo "== real Biome (skipped when not on PATH)"
if REAL_BIOME=$(command -v biome); then
  R=$(new_project)
  mkdir -p "$R/node_modules/.bin" "$R/src"
  ln -s "$REAL_BIOME" "$R/node_modules/.bin/biome"
  printf '{ "files": { "includes": ["src/**"] } }\n' >"$R/biome.json"
  printf 'const x = 1;\nexport { x };\n' >"$R/src/ok.ts"
  # Biome's organizeImports assist insists on a blank line before the export, so
  # run the real fixer first and let it normalise the file.
  run_hook "$FIXER" "$R" "$(edit_event "$R/src/ok.ts")"
  check_has "Real Biome: fix-on-write reports the repair" "$OUT$ERR" "was auto-fixed"
  run_hook "$GATE" "$R" "$(stop_event r1)"
  check "Real Biome: fixed, clean file passes the gate" "" "$OUT"

  printf 'var b = 2;\nconsole.log(b == 3);\n' >"$R/src/bad.ts"
  run_hook "$GATE" "$R" "$(stop_event r2)"
  check "Real Biome: a lint finding blocks" block "$(jq -r '.decision' <<<"$OUT")"
  check_has "Real Biome: the rule name reaches the reason" "$OUT" "noDoubleEquals"

  printf '{ nope\n' >"$R/biome.json"
  run_hook "$GATE" "$R" "$(stop_event r3)"
  check "Real Biome: a broken biome.json does not block" "" "$OUT"
  check_has "Real Biome: a broken biome.json is reported as a tool failure" "$ERR" "configuration is broken"
else
  echo "skip  no biome on PATH"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
