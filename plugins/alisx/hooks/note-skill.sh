#!/usr/bin/env bash
# PostToolUse on load_skill: a Skill store skill is now in use. Once per skill
# per session, Claude is asked to check with the person, when the work the
# skill guided is done, whether it helped, and to pass their answer to the
# skill's owner with send_skill_feedback. This is the counterpart of the alis
# CLI plugin's "how did it go" line under a skill: skills improve from what
# their users say.
set -u

hook_dir=$(cd "$(dirname "$0")" && pwd)
. "$hook_dir/lib.sh"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
[ "$(field tool_name)" = "${ALISX_TOOL_PREFIX}load_skill" ] || exit 0

# A refused load has nothing in use.
err_re='"is_?[Ee]rror"[[:space:]]*:[[:space:]]*true'
[[ $payload =~ $err_re ]] && exit 0

input="${payload#*\"tool_input\"}"
skill_re='"skill"[[:space:]]*:[[:space:]]*"([A-Za-z0-9._/-]{1,128})"'
[[ $input =~ $skill_re ]] || exit 0
skill="${BASH_REMATCH[1]}"
skill="${skill#skills/}"
# A continued read (offset) is the same skill.
offset_re='"offset"[[:space:]]*:[[:space:]]*[1-9]'
[[ $input =~ $offset_re ]] && exit 0

if f="$(session_file skills 2>/dev/null)"; then
  grep -qxF "$skill" "$f" 2>/dev/null && exit 0
  printf '%s\n' "$skill" >> "$f" 2>/dev/null || true
fi

context="The Skill store skill \`${skill}\` is now in use: follow it. When the work it guided is done (not before), ask the person in one short line how it went (helped, didn't help, or what was wrong) and, if they answer, send that to its owner with send_skill_feedback (rating up or down, their words as feedback). Ask once; if they don't answer, drop it. If a step of the skill was wrong or out of date, say so in that feedback."
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_escape "$context")"
exit 0
