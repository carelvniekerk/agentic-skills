#!/usr/bin/env bash
# UserPromptSubmit: tell the main session when the turn before this prompt
# ended in a tool call the user rejected or a request the user interrupted, or
# when the prompt carries preference or praise wording, so that the session can
# record the lesson with the dreaming:note skill.
#
# A hook cannot invoke a skill, and a prompt hook can only answer ok or not ok,
# so this hook states the facts and the main model decides whether to note.
# It runs synchronously, because only a synchronous hook can add context to the
# turn the prompt starts.
#
# Fails open and prints nothing when there is nothing to report: a broken nudge
# must never block or delay the user's prompt.
set -uo pipefail

readonly TAIL_LINES=400 # bounds the read on long sessions
readonly QUOTE_CHARS=300

command -v jq >/dev/null 2>&1 || exit 0

HERE=$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 0
# shellcheck source=memory-settings.sh
source "$HERE/memory-settings.sh" 2>/dev/null || exit 0

input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null) || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null) || cwd=""
prompt=$(jq -r '.prompt // empty' <<<"$input" 2>/dev/null) || prompt=""

memory_disabled "$cwd" && exit 0

# The window is every transcript entry after the previous typed prompt. If the
# current prompt is already written, it is skipped as the boundary. If no typed
# prompt is in the tail, the whole tail belongs to the last turn.
# Rejections are matched on the error result Claude Code writes when the user
# declines a permission prompt, so a denial by a guard hook or an auto-mode
# classifier does not count.
events='{"rejected":[],"interrupts":0}'
if [[ -n "$transcript" && -r "$transcript" ]]; then
  events=$(tail -n "$TAIL_LINES" "$transcript" 2>/dev/null |
    jq -c -R 'fromjson? // empty' 2>/dev/null |
    jq -s -c --arg p "$prompt" --argjson q "$QUOTE_CHARS" '
      def text:
        if type == "string" then .
        elif type == "array" then map(select(.type? == "text") | .text) | join("\n")
        else "" end;
      def typed:
        .type == "user" and (.isMeta | not)
        and ((.origin.kind? == "human")
          or (.origin == null and (.message.content | type) == "string"
              and ((.message.content | startswith("[Request interrupted")) | not)
              and ((.message.content | startswith("<")) | not)));
      # Anchored at the start of an error result, because the same words in
      # ordinary tool output (a grep of old transcripts) are not a rejection.
      def rejection:
        test("^\\s*(the )?user doesn.t want to (proceed with this tool use|take this action right now)"; "i");
      def reason:
        sub("(?s)^.*?STOP what you are doing and wait for the user to tell you how to proceed\\.?"; "")
        | sub("(?s)Note: The user.s next message may contain a correction or preference\\..*$"; "")
        | gsub("^\\s+|\\s+$"; "")
        | .[0:$q];
      . as $all
      | [range(0; length) | select($all[.] | typed)] as $h
      | (if ($h | length) > 0 and (($all[$h[-1]].message.content | text) == $p)
         then $h[:-1] else $h end) as $h2
      | (if ($h2 | length) > 0 then $h2[-1] + 1 else 0 end) as $start
      | $all[$start:] as $w
      | ([$w[] | select(.type == "assistant") | .message.content[]?
          | select(.type? == "tool_use") | {(.id): .name}] | add // {}) as $names
      | {
          rejected: [$w[] | select(.type == "user") | .message.content
            | if type == "array" then .[] else empty end
            | select(.type? == "tool_result" and .is_error == true)
            | (.content | text) as $t
            | select($t | rejection)
            | {tool: ($names[.tool_use_id] // "a tool"), said: ($t | reason)}],
          interrupts: [$w[] | select(.type == "user")
            | (.message.content | text)
            | select(startswith("[Request interrupted by user"))] | length
        }' 2>/dev/null) || events='{"rejected":[],"interrupts":0}'
  [[ -n "$events" ]] || events='{"rejected":[],"interrupts":0}'
fi

# Wording that often carries a correction, a standing preference or praise.
# A slash command is an invocation, not feedback, so it is never matched.
wording=0
shopt -s nocasematch
if [[ -n "$prompt" && "$prompt" != /* ]]; then
  re='(^|[^[:alpha:]])(from now on|going forward|in future|always|never|don.?t|do not|stop doing|instead|i prefer|i.d rather|i told you|i already said|as i said|that.s wrong|not like that|perfect|exactly what i|well done|good job|keep doing|nice work)([^[:alpha:]]|$)'
  [[ "$prompt" =~ $re ]] && wording=1
fi
shopt -u nocasematch

nrej=$(jq -r '.rejected | length' <<<"$events" 2>/dev/null) || nrej=0
nint=$(jq -r '.interrupts' <<<"$events" 2>/dev/null) || nint=0
((nrej == 0 && nint == 0 && wording == 0)) && exit 0

context=$(jq -r --argjson w "$wording" --arg cwd "$cwd" '
  def plural($n; $one; $many): if $n == 1 then $one else $many end;
  (.rejected | length) as $r
  | [
      (if $r > 0 then
        "Before this prompt, the user rejected \($r) \(plural($r; "tool call"; "tool calls")) (\([.rejected[].tool] | unique | join(", ")))."
       else empty end),
      (.rejected[] | select(.said != "") | "Text the user gave with the rejection of \(.tool): \"\(.said)\""),
      (if .interrupts > 0 then
        "Before this prompt, the user interrupted \(.interrupts) \(plural(.interrupts; "request"; "requests"))."
       else empty end),
      (if $w == 1 then "The prompt contains wording that often states a preference, a correction or praise." else empty end),
      (if $cwd != "" then "Working directory: \($cwd)." else empty end),
      "The dreaming:note skill records a correction, a standing preference or a confirmed approach as a memory and counts repeats of the same lesson. A one-off instruction for the current task is not a lesson."
    ]
  | join("\n")' <<<"$events" 2>/dev/null) || exit 0

jq -n --arg c "$context" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $c
  }
}'
exit 0
