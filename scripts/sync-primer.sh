#!/usr/bin/env bash
# Copy the primer from its one source, the alisx plugin's alisx:dbd skill, to
# the alisx-hooks plugin, whose session-start hook injects it. Run it after
# editing plugins/alisx/skills/dbd/SKILL.md; tests/release-guard.sh fails while
# the two differ.
set -eu
repo="$(cd "$(dirname "$0")/.." && pwd)"
skill="$repo/plugins/alisx/skills/dbd/SKILL.md"
out="$repo/plugins/alisx-hooks/context/primer.md"
# The skill without its front matter (between the first two --- lines) and the
# blank line after it.
awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; body=1; next} body' "$skill" | sed '1{/^$/d;}' > "$out"
echo "primer -> $out"
