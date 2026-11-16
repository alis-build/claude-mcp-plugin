#!/usr/bin/env bash
# PreToolUse on the Alis MCP server's tools: the permission gate.
#
# The server makes every tool either a read or a write, never both, so that a
# client can let the reads run and ask the person about the rest. This hook
# does that from tool-policy.tsv (see its header):
#
#   - reads run without a permission prompt;
#   - destructive writes, and any call whose arguments ask for production, a
#     reveal or an override, are asked about in every permission mode;
#   - other writes keep Claude Code's own permission handling;
#   - a call whose arguments carry a secret-looking value is refused, with the
#     kinds found (never the values), so that Claude takes it out first:
#     everything sent to the server reaches people or the Skill store.
#
# This gate concerns only this plugin's server, so it runs whether or not the
# alis CLI's plugin is enabled.
set -u

hook_dir=$(cd "$(dirname "$0")" && pwd)
. "$hook_dir/lib.sh"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

full="$(field tool_name)"
case "$full" in "$ALISX_TOOL_PREFIX"*) ;; *) exit 0 ;; esac
tool="${full#"$ALISX_TOOL_PREFIX"}"
[[ $tool =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

answer() {  # answer DECISION REASON
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
    "$1" "$(json_escape "$2")"
  exit 0
}

# The arguments, as sent. Everything after "tool_input" is enough: the fields
# before it are ids and paths.
input="${payload#*\"tool_input\"}"
[ "$input" = "$payload" ] && input=""

# 1. A secret never goes to the server.
kinds="$(secret_kinds "$input")"
if [ -n "$kinds" ]; then
  answer deny "AlisX: this ${tool} call carries what looks like a secret (${kinds}). Everything sent to Alis Build is stored and read by people. Take the value out (or replace it with [REDACTED]) and call again; never paste the value into chat."
fi

# 2. The policy.
decision=none
reason=""
while IFS='	' read -r pattern d r; do
  case "$pattern" in ''|'#'*) continue ;; esac
  if [[ $tool =~ $pattern ]]; then decision="$d"; reason="$r"; break; fi
done < "$hook_dir/tool-policy.tsv"

# 3. Arguments that always need the person.
guard_re='"(confirm_production|reveal|approve|force)"[[:space:]]*:[[:space:]]*true'
if [[ $input =~ $guard_re ]]; then
  flag="${BASH_REMATCH[1]}"
  case "$flag" in
    confirm_production) why="targets production" ;;
    reveal) why="reveals secret values into this conversation" ;;
    approve) why="approves an action the person's automation tier holds for them" ;;
    force) why="overrides a safety check" ;;
  esac
  answer ask "AlisX: this ${tool} call ${why} (${flag}). It needs your explicit approval."
fi

case "$decision" in
  allow) answer allow "AlisX: ${tool} only reads." ;;
  ask) answer ask "AlisX: ${reason:-this call changes something on Alis Build.}" ;;
esac
exit 0
