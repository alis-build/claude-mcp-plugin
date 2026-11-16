#!/usr/bin/env bash
# Refresh tests/fixtures/mcp-tools.txt from the MCP server's source: every tool
# the server registers is a key of the `scopes` map in tools.go. Run it when the
# server gains tools, then name each new one in plugins/alisx/hooks/gate-tools.sh
# and in the PreToolUse matcher in hooks.json; tests/release-guard.sh fails
# until then.
#
#   scripts/sync-tools.sh [path/to/alis/build/os/mcp/v1]
set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${1:-$HOME/alis.build/alis/build/os/mcp/v1}"
[ -f "$src/tools.go" ] || { echo "no tools.go under $src" >&2; exit 1; }

out="$repo/tests/fixtures/mcp-tools.txt"
{
  echo "# The Alis MCP server's tools (alis.os.mcp.v1), from the scopes map in tools.go."
  echo "# Refreshed by scripts/sync-tools.sh; every name belongs in gate-tools.sh and its matcher."
  sed -n '/^var scopes = map\[string\]string{/,/^}/p' "$src/tools.go" \
    | sed -n -E 's/^[[:space:]]*"([a-z0-9_]+)"[[:space:]]*:.*/\1/p'
} > "$out"
echo "$(grep -vc '^#' "$out") tools -> $out"
