#!/usr/bin/env bash
# SessionStart: what Claude should know about Alis Build before the first
# prompt, as one additionalContext.
#
#   1. The primer (context/primer.md, a copy of the alisx plugin's alisx:dbd
#      skill kept by scripts/sync-primer.sh) inside Alis Build work: an
#      ~/alis.build workspace, or a Go module that uses Alis-defined packages.
#      Elsewhere, and on resume, compact and fork (which already carried the
#      primer once), the short digest (context/digest.md).
#   2. Inside an ~/alis.build/<org>/{build,define}/... service folder, the
#      package id and where its other half (contract or implementation) lives.
#
# ALIS_PRIMER=full|digest|off overrides the choice in 1, as in the alis CLI's
# own plugin. When that plugin (alis@alis) is enabled it injects its CLI primer
# itself, and this hook says only that the MCP server is here too.
#
set -u

case $0 in */*) hook_dir=${0%/*} ;; *) hook_dir=. ;; esac
. "$hook_dir/lib.sh"
ctx_dir="$hook_dir/../context"

payload="$(cat 2>/dev/null || true)"
source_="$(field source)"
dir="$(project_dir)"

# Old per-session state goes at each start; a day is far longer than any hook
# needs it.
if d="$(state_dir)" && [ -d "$d/sessions" ]; then
  find "$d/sessions" -type f -mtime +1 -exec rm -f {} + 2>/dev/null || true
fi

emit() {  # emit CONTEXT [SYSTEM_MESSAGE]
  local out='{'
  [ -n "${2:-}" ] && out="$out\"systemMessage\":\"$(json_escape "$2")\","
  out="$out\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$(json_escape "$1")\"}}"
  printf '%s\n' "$out"
}

if cli_plugin_enabled; then
  [ "${ALIS_PRIMER:-}" = off ] && exit 0
  emit "The AlisX plugin's MCP server (plugin:alisx:alis, https://mcp.alisx.com) is also connected in this session: the Alis Build Skill store and the person's conversations with Alis Build specialists, as tools. The alis CLI plugin's primer applies; where an MCP tool covers a step, either path is fine."
  exit 0
fi

# 1. Primer or digest.
want=digest
in_workspace "$dir" && want=full
case "$source_" in resume|compact|fork) want=digest ;; esac
case "${ALIS_PRIMER:-}" in
  off) want=off ;;
  full|digest) want="$ALIS_PRIMER" ;;
esac

context=""
if [ "$want" != off ]; then
  primer="$ctx_dir/primer.md"
  [ "$want" = digest ] && [ -f "$ctx_dir/digest.md" ] && primer="$ctx_dir/digest.md"
  [ -f "$primer" ] && context="$(cat "$primer")"

fi

# 2. The service this session opened in, from the workspace layout:
#    build  = <root>/alis.build/<org>/build/<path...>
#    define = <root>/alis.build/<org>/define/<org>/<path...>
#    package id = <org>.<path with / as .> up to the vN segment.
service_context() {
  local root rest org side relpath definedir builddir pkg s found=0
  local -a parts segs svc
  case "$dir" in */alis.build/*) ;; *) return 0 ;; esac
  root="${dir%%/alis.build/*}/alis.build"
  rest="${dir#*/alis.build/}"
  IFS='/' read -ra parts <<< "$rest"
  org="${parts[0]:-}"; side="${parts[1]:-}"
  [ -n "$org" ] && [ -n "$side" ] || return 0
  case "$side" in
    build)  segs=("${parts[@]:2}") ;;
    define) [ "${parts[2]:-}" = "$org" ] || return 0   # vendored google/ and the like
            segs=("${parts[@]:3}") ;;
    *)      return 0 ;;
  esac
  svc=()
  for s in ${segs[@]+"${segs[@]}"}; do
    [ -n "$s" ] || continue
    svc+=("$s")
    if [[ $s =~ ^v[0-9]+$ ]]; then found=1; break; fi
  done
  [ "${#svc[@]}" -gt 0 ] || return 0
  relpath="$(IFS=/; printf '%s' "${svc[*]}")"
  definedir="$root/$org/define/$org/$relpath"
  builddir="$root/$org/build/$relpath"
  pkg=""
  [ "$found" -eq 1 ] && pkg="$org.$(IFS=.; printf '%s' "${svc[*]}")"

  protos() {
    local f names=""
    for f in "$1"/*.proto; do [ -e "$f" ] && names="$names, $(basename "$f")"; done
    [ -n "$names" ] && printf '  Proto files: %s\n' "${names#, }"
    return 0
  }
  if [ "$side" = build ]; then
    printf 'This session is inside an Alis Build service implementation (build) directory.\n'
    [ -n "$pkg" ] && printf '  Package ID:  %s\n' "$pkg"
    if [ -d "$definedir" ]; then
      printf '  Its protobuf definitions (the API contract, the DBD "Define" step) are here:\n    %s\n' "$definedir"
      protos "$definedir"
    else
      printf '  Expected definitions at %s (not found on disk).\n' "$definedir"
    fi
  else
    printf 'This session is inside an Alis Build definitions (define) directory: the protobuf API contract.\n'
    [ -n "$pkg" ] && printf '  Package ID:  %s\n' "$pkg"
    protos "$dir"
    if [ -d "$builddir" ]; then
      printf '  Its implementation (the DBD "Build" step) is here:\n    %s\n' "$builddir"
    else
      printf '  This contract has no build/ implementation directory yet.\n'
    fi
  fi
}
svc="$(service_context 2>/dev/null || true)"
[ -n "$svc" ] && context="${context:+$context

}$svc"

[ -n "$context" ] || exit 0
emit "$context"
exit 0
