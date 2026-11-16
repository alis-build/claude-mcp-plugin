#!/usr/bin/env bash
# PreToolUse on the Alis Build MCP server's tools.
#
# This hook only ever asks the person or refuses; it never answers for a read
# or an ordinary write, which keep Claude's own permission handling. Every
# answer it can give is one of the literal JSON lines below.
#
#   - A call whose arguments carry a secret-looking value is refused, so that
#     Claude takes the value out first: what the server is sent is stored and
#     read by people.
#   - A call whose arguments ask for production, a reveal or a forced change is
#     asked about, in every permission mode.
#   - The writes the server marks destructive are asked about, in every mode.
#   - Under Claude Code's name for this plugin's server
#     (mcp__plugin_alisx_alis__<tool>), a tool the server adds before this file
#     names it is asked about when its name says it deploys, removes or touches
#     secrets.
#
# Hosts name the server differently, so a tool is known by the end of its name
# (__<tool>), as the matcher in hooks.json does. Self-contained on purpose: no
# sourced files and no generated output, so that what it runs and says can be
# read here in full. The secret patterns are data, in secret-patterns.tsv.
set -u

case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
payload=$(cat)

name_re='"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)"'
[[ $payload =~ $name_re ]] || exit 0
full=${BASH_REMATCH[1]}
tool=${full##*__}

# The call's arguments: everything after "tool_input" (the fields before it
# are ids and paths).
args=${payload#*\"tool_input\"}
[ "$args" = "$payload" ] && exit 0

# 1. A secret is never sent.
while IFS='	' read -r kind pattern; do
  case $kind in ''|'#'*) continue ;; esac
  found=$(grep -oE -e "$pattern" <<< "$args" | grep -vE -f "$here/secret-placeholders.txt")
  if [ -n "$found" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AlisX: this call carries what looks like a secret (a key, token, password or private key). What it sends is stored and read by people. Take the value out, or put [REDACTED] in its place, and call again. Never paste the value into chat."}}'
    exit 0
  fi
done < "$here/secret-patterns.tsv"

# 2. Arguments that always need the person.
production_re='"confirm_production"[[:space:]]*:[[:space:]]*true'
reveal_re='"reveal"[[:space:]]*:[[:space:]]*true'
force_re='"force"[[:space:]]*:[[:space:]]*true'
if [[ $args =~ $production_re ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: this call targets production. It needs your explicit go-ahead."}}'
  exit 0
fi
if [[ $args =~ $reveal_re ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: this call reveals secret values into this conversation. It needs your explicit go-ahead."}}'
  exit 0
fi
if [[ $args =~ $force_re ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: this call overrides a safety check. It needs your explicit go-ahead."}}'
  exit 0
fi

# 3. The server's tools, each named. Keep this list and the matcher in
#    hooks.json in step with tests/fixtures/mcp-tools.txt (the release guard
#    checks both).
case $tool in
  # Skills: reads, and writes that are not destructive. Claude's own handling.
  search_skills|list_skills|preview_skill|load_skill|read_skill_file|list_skill_revisions) exit 0 ;;
  create_skill|request_skill|send_skill_feedback) exit 0 ;;
  # Skills: writes the server marks destructive.
  update_skill)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: publishes a new version of this skill to everyone who uses it."}}'
    exit 0 ;;
  restore_skill_version)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: publishes an earlier version as the newest version of this skill, for everyone who uses it."}}'
    exit 0 ;;
  delete_skill)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: deletes this skill for everyone it is shared with. This cannot be undone."}}'
    exit 0 ;;
  # Conversations: reads, and writes that people read. Claude's own handling.
  list_conversations|search_conversations|get_conversation|read_attachment|wait_for_reply) exit 0 ;;
  start_conversation|send_message|resolve_conversation|reopen_conversation) exit 0 ;;
esac

# 4. Tools the server adds before this file names them: only under the name
#    Claude Code gives this plugin's own server.
case $full in mcp__plugin_alisx_alis__*) ;; *) exit 0 ;; esac
changes_re='(^|_)(delete|destroy|uninstall|unset|purge|revoke|cancel|rollback|deploy|release|promote)(_|$)'
secrets_re='(secret|credential|password|token|reveal)'
if [[ $tool =~ $changes_re ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: this call changes or removes something on the Alis Build platform."}}'
  exit 0
fi
if [[ $tool =~ $secrets_re ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AlisX: this call may return secret values into this conversation."}}'
  exit 0
fi
exit 0
