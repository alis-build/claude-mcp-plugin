#!/usr/bin/env bash
# PostToolUse on every tool: a secret-looking value in a tool's result or its
# own arguments (`cat .env`, `printenv`, a written config, a conversation's
# file) has reached Claude. It cannot be unprinted, so Claude is told the
# kinds found, not to repeat them, and that they may need rotating; the person
# sees one line naming the kinds. Values never appear in either, and each value
# is reported once per session (only a hash of it is kept, under the plugin's
# data folder, and removed after a day).
#
# The alis CLI's plugin warns about secrets itself; with it enabled this hook
# steps aside. ALISX_SECRETS=off turns it off.
set -u

[ "${ALISX_SECRETS:-}" = off ] && exit 0

case $0 in */*) hook_dir=${0%/*} ;; *) hook_dir=. ;; esac
. "$hook_dir/lib.sh"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
cli_plugin_enabled && exit 0

# The arguments and the result: everything after "tool_input".
body="${payload#*\"tool_input\"}"
[ "$body" = "$payload" ] && exit 0

hits="$(secret_hits "$body")"
[ -n "$hits" ] || exit 0

seen="$(session_file secrets 2>/dev/null || true)"
fresh=""
while IFS='	' read -r kind value; do
  [ -n "$value" ] || continue
  sum="$(printf '%s' "$value" | cksum | cut -d' ' -f1)"
  if [ -n "$seen" ]; then
    grep -qx "$sum" "$seen" 2>/dev/null && continue
    printf '%s\n' "$sum" >> "$seen" 2>/dev/null || true
  fi
  fresh="$fresh
$kind"
done <<< "$hits"

kinds="$(printf '%s' "$fresh" | sed '/^$/d' | awk '!seen[$0]++' | paste -sd, - | sed 's/,/, /g')"
[ -n "$kinds" ] || exit 0

tool="$(field tool_name)"
context="AlisX: the ${tool:-last tool} call put what looks like a secret into this conversation (${kinds}). Do not repeat, quote, summarise or send the value anywhere, including to Alis Build tools. Tell the person in one line which kinds appeared and that they may need rotating; use a placeholder such as [REDACTED] if it must be referred to."
message="AlisX: a secret-looking value (${kinds}) appeared in ${tool:-a tool call}. It may need rotating."
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
  "$(json_escape "$message")" "$(json_escape "$context")"
exit 0
