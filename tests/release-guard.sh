#!/usr/bin/env bash
# Release guard: what must hold before a version of either plugin is published.
# CI runs it on every push and pull request.
#
#   plugins/alisx        submitted to the Claude plugin directory: the MCP
#                        server, skills and commands. No hooks and no scripts
#                        (the directory refuses both from an organization that
#                        is not Verified).
#   plugins/alisx-hooks  this marketplace only: the Claude Code hooks.
#
#   tests/release-guard.sh
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$repo/plugins/alisx"
hooks="$repo/plugins/alisx-hooks"
market="$repo/.claude-plugin/marketplace.json"
fail=0
no() { echo "FAIL: $*" >&2; fail=1; }

command -v jq >/dev/null || { echo "jq is needed" >&2; exit 2; }

# 1. One version per plugin, the same in its manifest and its marketplace
#    entry (which is what installers resolve), and a changelog entry for the
#    directory plugin's.
for p in "$plugin" "$hooks"; do
  n="$(jq -r .name "$p/.claude-plugin/plugin.json")"
  pv="$(jq -r .version "$p/.claude-plugin/plugin.json")"
  mv_="$(jq -r --arg n "$n" '.plugins[] | select(.name == $n) | .version' "$market")"
  [ "$pv" = "$mv_" ] || no "$n: version skew: plugin.json=$pv marketplace.json=${mv_:-missing}"
done
version="$(jq -r .version "$plugin/.claude-plugin/plugin.json")"
grep -q "^## \[$version\]" "$repo/CHANGELOG.md" || no "CHANGELOG.md has no entry for $version"
name="$(jq -r .name "$plugin/.claude-plugin/plugin.json")"
jq -e --arg n "$name" '.dependencies | index($n)' "$hooks/.claude-plugin/plugin.json" >/dev/null \
  || no "alisx-hooks must depend on $name"

# 2. The MCP server is the fixed production address (the directory and Chat
#    refuse variables in a remote URL).
url="$(jq -r '.mcpServers.alis.url' "$plugin/.mcp.json")"
[ "$url" = "https://mcp.alisx.com" ] || no ".mcp.json: alis url is $url"
[ "$(jq -r '.mcpServers.alis.type' "$plugin/.mcp.json")" = http ] || no ".mcp.json: alis type must be http"

# 3. The directory plugin carries only what the directory accepts from an
#    organization that is not Verified: Markdown, text, JSON, YAML and images,
#    nothing that starts with #!, and no hooks.
[ ! -e "$plugin/hooks" ] || no "plugins/alisx must not ship hooks/ (they live in plugins/alisx-hooks)"
jq -e 'has("hooks") | not' "$plugin/.claude-plugin/plugin.json" >/dev/null || no "plugin.json must not declare hooks"
[ ! -e "$plugin/bin" ] || no "a top-level bin/ makes the plugin uninstallable in Chat and Cowork"
while IFS= read -r f; do
  rel="${f#"$plugin"/}"
  case "$rel" in
    *.md|*.txt|*.json|*.yaml|*.yml|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|LICENSE|.gitignore) ;;
    *) no "plugins/alisx/$rel is not a file type the directory accepts" ;;
  esac
  [ "$(head -c 2 "$f")" != '#!' ] || no "plugins/alisx/$rel starts with #!"
done < <(find "$plugin" -type f)
# The listing icon: a square PNG, 512 to 2048 px.
icon="$(jq -r '.icon // empty' "$plugin/.claude-plugin/plugin.json")"
if [ -z "$icon" ] || [ ! -f "$plugin/$icon" ]; then
  no "plugin.json icon is missing or names no file"
else
  w=$((16#$(od -An -tx1 -j16 -N4 "$plugin/$icon" | tr -d ' \n')))
  h=$((16#$(od -An -tx1 -j20 -N4 "$plugin/$icon" | tr -d ' \n')))
  case "$icon" in *.png) ;; *) no "the icon must be a PNG" ;; esac
  [ "$w" = "$h" ] && [ "$w" -ge 512 ] && [ "$w" -le 2048 ] || no "the icon must be square, 512 to 2048 px (is ${w}x${h})"
fi

# 4. What Chat and Cowork accept: skill and command front matter that is only
#    what Chat reads.
for f in "$plugin"/skills/*/SKILL.md "$plugin"/commands/*.md; do
  keys="$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm && /^[A-Za-z_-]+:/ {sub(/:.*/, ""); print}' "$f")"
  for k in $keys; do
    case "$k" in name|description) ;; *) no "$f: front matter key '$k' is not one Chat accepts" ;; esac
  done
  printf '%s\n' "$keys" | grep -qx description || no "$f has no description"
done

# 5. The hooks plugin: every command `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh"`
#    (the interpreter named, the path the plugin's own), and every script parses.
jq -e '.hooks | type == "object"' "$hooks/hooks/hooks.json" >/dev/null || no "hooks.json has no hooks object"
while IFS= read -r cmd; do
  case "$cmd" in
    'bash "${CLAUDE_PLUGIN_ROOT}/'*'"') rel="${cmd#bash \"\$\{CLAUDE_PLUGIN_ROOT\}/}"; rel="${rel%\"}" ;;
    *) no "hook command is not bash \"\${CLAUDE_PLUGIN_ROOT}/...\": $cmd"; continue ;;
  esac
  [ -f "$hooks/$rel" ] || no "hook script missing: $rel"
done < <(jq -r '.hooks[][] | .hooks[] | .command' "$hooks/hooks/hooks.json")
for f in "$hooks"/hooks/*.sh; do bash -n "$f" || no "$f does not parse"; done
grep -q "plugin_${name}_alis__" "$hooks/hooks/hooks.json" || no "hooks.json matchers do not name plugin_${name}_alis__"
grep -q "mcp__plugin_${name}_alis__" "$hooks/hooks/gate-tools.sh" || no "gate-tools.sh does not name mcp__plugin_${name}_alis__"

# 6. The gate stays readable in full: it never answers allow, builds no JSON
#    (no printf) and sources nothing. Every tool the server serves is named both
#    in the gate and in its matcher.
gate="$hooks/hooks/gate-tools.sh"
! grep -q '"allow"' "$gate" || no "gate-tools.sh must never answer allow"
! grep -q 'printf' "$gate" || no "gate-tools.sh must print literal JSON only (no printf)"
! grep -qE '^[[:space:]]*(\.|source)[[:space:]]' "$gate" || no "gate-tools.sh must not source other files"
matcher="$(jq -r '.hooks.PreToolUse[0].matcher' "$hooks/hooks/hooks.json")"
while IFS= read -r t; do
  case "$t" in ''|'#'*) continue ;; esac
  sed '/^# 4\./,$d' "$gate" | grep -v '^[[:space:]]*#' | grep -qw -- "$t" || no "tool $t is not named in gate-tools.sh"
  printf '%s' "$matcher" | grep -qw -- "$t" || no "tool $t is not in the PreToolUse matcher"
done < "$repo/tests/fixtures/mcp-tools.txt"

# 7. One primer: the hooks plugin injects a copy of the alisx:dbd skill.
expected="$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; body=1; next} body' "$plugin/skills/dbd/SKILL.md" | sed '1{/^$/d;}')"
[ "$expected" = "$(cat "$hooks/context/primer.md")" ] \
  || no "plugins/alisx-hooks/context/primer.md differs from the alisx:dbd skill: run scripts/sync-primer.sh"

# 8. What the directory holds or refuses anywhere.
if find "$repo" -path "$repo/.git" -prune -o \( -name .DS_Store -o -name Thumbs.db -o -name desktop.ini -o -name __MACOSX \) -print | grep -q .; then
  no "OS junk files (.DS_Store and the like) are present"
fi
big="$(find "$plugin" "$hooks" -type f -size +256k ! -name '*.png' -print)"
[ -z "$big" ] || no "files over 256 KiB: $big"
for p in "$plugin" "$hooks"; do
  [ -f "$p/README.md" ] || no "${p#"$repo"/} needs its own README.md"
  [ "$(sed '/^```/,/^```/d' "$p/README.md" 2>/dev/null | wc -w)" -ge 40 ] || no "${p#"$repo"/} README needs at least 40 words outside code blocks"
done

# 9. Claude Code's own validator, where it is installed (CI may not have it).
if command -v claude >/dev/null 2>&1; then
  claude plugin validate --strict --profile directory "$plugin" >/dev/null 2>&1 \
    || no "claude plugin validate --strict --profile directory plugins/alisx fails (run it to see why)"
  claude plugin validate "$hooks" >/dev/null 2>&1 \
    || no "claude plugin validate plugins/alisx-hooks fails (run it to see why)"
  claude plugin validate --strict "$repo" >/dev/null 2>&1 \
    || no "claude plugin validate --strict . fails for the marketplace"
else
  echo "note: claude is not installed; skipped claude plugin validate" >&2
fi

[ "$fail" -eq 0 ] && echo "release guard: ok ($name $version, alisx-hooks $(jq -r .version "$hooks/.claude-plugin/plugin.json"))"
exit "$fail"
