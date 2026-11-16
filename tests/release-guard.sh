#!/usr/bin/env bash
# Release guard: what must hold before a version of the plugin is published.
# CI runs it on every push and pull request.
#
#   tests/release-guard.sh
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$repo/plugins/alisx"
fail=0
no() { echo "FAIL: $*" >&2; fail=1; }

command -v jq >/dev/null || { echo "jq is needed" >&2; exit 2; }

# 1. One version everywhere: the marketplace entry is what installers resolve.
pv="$(jq -r .version "$plugin/.claude-plugin/plugin.json")"
mv_="$(jq -r '.plugins[] | select(.name == "alisx") | .version' "$repo/.claude-plugin/marketplace.json")"
[ "$pv" = "$mv_" ] || no "version skew: plugin.json=$pv marketplace.json=$mv_"
grep -q "^## \[$pv\]" "$repo/CHANGELOG.md" || no "CHANGELOG.md has no entry for $pv"

# 2. The MCP server is the fixed production address (the directory and Chat
#    refuse variables in a remote URL).
url="$(jq -r '.mcpServers.alis.url' "$plugin/.mcp.json")"
[ "$url" = "https://mcp.alisx.com" ] || no ".mcp.json: alis url is $url"
[ "$(jq -r '.mcpServers.alis.type' "$plugin/.mcp.json")" = http ] || no ".mcp.json: alis type must be http"

# 3. Hooks: valid JSON, every command a quoted plugin-relative executable, and
#    every script parses.
jq -e '.hooks | type == "object"' "$plugin/hooks/hooks.json" >/dev/null || no "hooks.json has no hooks object"
while IFS= read -r cmd; do
  case "$cmd" in
    '"${CLAUDE_PLUGIN_ROOT}/'*'"') rel="${cmd#\"\$\{CLAUDE_PLUGIN_ROOT\}/}"; rel="${rel%\"}" ;;
    *) no "hook command is not a quoted \${CLAUDE_PLUGIN_ROOT} path: $cmd"; continue ;;
  esac
  [ -x "$plugin/$rel" ] || no "hook script missing or not executable: $rel"
done < <(jq -r '.hooks[][] | .hooks[] | .command' "$plugin/hooks/hooks.json")
for f in "$plugin"/hooks/*.sh; do bash -n "$f" || no "$f does not parse"; done
# The matchers name the plugin's own server: a rename must change them too.
name="$(jq -r .name "$plugin/.claude-plugin/plugin.json")"
grep -q "mcp__plugin_${name}_alis__" "$plugin/hooks/hooks.json" || no "hooks.json matchers do not name mcp__plugin_${name}_alis__"
grep -q "ALISX_TOOL_PREFIX='mcp__plugin_${name}_alis__'" "$plugin/hooks/lib.sh" || no "lib.sh tool prefix does not match the plugin name"

# 4. Every tool the server serves has an explicit rule above the fallbacks.
rules="$(sed '/^# --- fallbacks/,$d' "$plugin/hooks/tool-policy.tsv" | grep -v '^#' | grep -v '^$')"
while IFS= read -r t; do
  case "$t" in ''|'#'*) continue ;; esac
  matched=0
  while IFS='	' read -r pattern decision _; do
    [[ $t =~ $pattern ]] && { matched=1; break; }
  done <<EOF
$rules
EOF
  [ "$matched" -eq 1 ] || no "tool $t has no rule in tool-policy.tsv (above the fallbacks)"
done < "$repo/tests/fixtures/mcp-tools.txt"
awk -F'\t' '!/^#/ && NF { if ($2 != "allow" && $2 != "ask" && $2 != "none") { print "bad decision: " $0; bad=1 } } END { exit bad }' \
  "$plugin/hooks/tool-policy.tsv" || no "tool-policy.tsv has a decision other than allow, ask or none"

# 5. What Chat and Cowork accept: no top-level bin/ (the whole plugin is
#    refused), and skills and commands whose front matter is only what Chat
#    reads.
[ ! -e "$plugin/bin" ] || no "a top-level bin/ makes the plugin uninstallable in Chat and Cowork"
for f in "$plugin"/skills/*/SKILL.md "$plugin"/commands/*.md; do
  keys="$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm && /^[A-Za-z_-]+:/ {sub(/:.*/, ""); print}' "$f")"
  for k in $keys; do
    case "$k" in name|description) ;; *) no "$f: front matter key '$k' is not one Chat accepts" ;; esac
  done
  printf '%s\n' "$keys" | grep -qx description || no "$f has no description"
done

# 6. What the directory holds or refuses.
if find "$repo" -path "$repo/.git" -prune -o \( -name .DS_Store -o -name Thumbs.db -o -name desktop.ini -o -name __MACOSX \) -print | grep -q .; then
  no "OS junk files (.DS_Store and the like) are present"
fi
big="$(find "$plugin" -type f -size +256k ! -name '*.png' ! -name '*.svg' ! -name '*.jpg' -print)"
[ -z "$big" ] || no "files over 256 KiB: $big"
[ -f "$plugin/README.md" ] || no "the plugin folder needs its own README.md"
[ "$(sed '/^```/,/^```/d' "$plugin/README.md" | wc -w)" -ge 40 ] || no "the plugin README needs at least 40 words outside code blocks"

# 7. Claude Code's own validator, where it is installed (CI may not have it).
if command -v claude >/dev/null 2>&1; then
  claude plugin validate --strict --profile directory "$plugin" >/dev/null 2>&1 \
    || no "claude plugin validate --strict --profile directory plugins/alisx fails (run it to see why)"
  claude plugin validate --strict "$repo" >/dev/null 2>&1 \
    || no "claude plugin validate --strict . fails for the marketplace"
else
  echo "note: claude is not installed; skipped claude plugin validate" >&2
fi

[ "$fail" -eq 0 ] && echo "release guard: ok ($name $pv)"
exit "$fail"
