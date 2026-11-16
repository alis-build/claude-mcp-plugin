#!/usr/bin/env bash
# UserPromptSubmit: route a prompt that names its Alis Build destination.
#
#   "alis, …" / "hey alis …" / "ask alis to …"  -> invoke alisx:discover
#   "capture this as a skill" and the like       -> invoke alisx:capture
#   a conversation reference (tickets/<id>)      -> read it first
#   an Ideate project (ideas/<id>), with the CLI -> alis ideate context first
#   plan mode on Alis Build work                 -> check the Skill store once
#
# Matching is local and costs a few milliseconds; nothing about the prompt
# leaves the machine. Anything else gets no output at all. When the alis CLI's
# plugin is enabled, it routes these phrases itself, so this hook steps aside.
set -u

hook_dir=$(cd "$(dirname "$0")" && pwd)
. "$hook_dir/lib.sh"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
cli_plugin_enabled && exit 0

prompt="$(prompt_text)"
[ -n "$prompt" ] || exit 0
low="$(lower "$prompt")"
notes=""
add() { notes="${notes:+$notes
}$1"; }

# Wake words: only at the start of the prompt, or "ask alis to", so that a
# prompt that merely mentions the platform ("the alis cli provides…") is not
# taken as addressed to it.
wake='^([[:space:]]|\\n)*((hey|hi|ok|okay)[[:space:]]+)?alis([[:space:]]*[,:!]|[[:space:]]*$)'
ask='(^|[^a-z])ask[[:space:]]+alis[[:space:]]+(to|for|how|about|whether|if)[[:space:]]'
capture='(capture|save|record|turn|make)[[:space:]]+(this|that|it|what[[:space:]]+(we|i|you)[[:space:]]+(just[[:space:]]+)?did)[[:space:]]+(as|into)[[:space:]]+(a|an)[[:space:]]+((alis|team|reusable)[[:space:]]+)?skill|(^|[^a-z])skillify|should[[:space:]]+have[[:space:]]+a[[:space:]]+skill[[:space:]]+for[[:space:]]+this'

if [[ $low =~ $capture ]]; then
  add "The person asked to capture this work as an Alis Build skill. Invoke the alisx:capture skill now."
elif [[ $low =~ $wake ]] || [[ $low =~ $ask ]]; then
  add "The person addressed Alis by name. Invoke the alisx:discover skill now to find and load the right Alis Build skill before doing anything else."
fi

# A referenced conversation is read before anything is proposed.
ticket_re='(^|[^A-Za-z0-9_/-])(tickets/[A-Za-z0-9_-]{3,})'
if [[ $prompt =~ $ticket_re ]]; then
  add "The prompt references the Alis Build conversation ${BASH_REMATCH[2]}. Read it with get_conversation before proposing changes."
fi

# Ideate projects are read through the CLI until the MCP server serves them.
idea_re='(^|[[:space:]("'"'"'`])(ideas/[A-Za-z0-9_-]{3,})'
if has_cli && [[ $prompt =~ $idea_re ]]; then
  add "The prompt references the Alis Ideate project ${BASH_REMATCH[2]}. Run \`alis ideate context ${BASH_REMATCH[2]#ideas/}\` first."
fi

# Plan mode on platform work: one Skill store search belongs in the plan.
plan_re='"permission_mode"[[:space:]]*:[[:space:]]*"plan"'
platform_re='(^|[^a-z])(alis|define|deploy|protobuf|proto|spanner|protobundle|pub/?sub|terraform|playground|code block|build environment|adk)([^a-z]|$)'
if [[ $payload =~ $plan_re ]] && { in_workspace "$(project_dir)" || [[ $low =~ $platform_re ]]; }; then
  add "Plan mode on Alis Build work: run search_skills once for the planned outcome and name any skill whose description clearly fits in the plan, to load and follow once the plan is approved."
fi

[ -n "$notes" ] || exit 0
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(json_escape "$notes")"
exit 0
