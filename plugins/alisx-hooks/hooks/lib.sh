# Shared helpers for the AlisX hooks. Sourced, never run.
#
# Every hook reads one JSON event on stdin and answers with nothing or one JSON
# object on stdout. They stay in bash (3.2-compatible, for macOS) with grep and
# sed only: no jq, python or node, so they run wherever Claude Code runs hooks
# (the terminal, the desktop app, cloud sessions, Cowork). Every failure path
# is silent: a hook must never break a session.

# json_escape TEXT: TEXT as the inside of a JSON string.
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# field NAME: the first top-level-looking string field NAME in $payload,
# unescaped only as far as a value without quotes needs. Enough for ids and
# names; never used for free text.
field() {
  printf '%s' "$payload" | tr '\n\r' '  ' \
    | sed -n -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -n 1
}

# prompt_text: the prompt of a UserPromptSubmit event, still JSON-escaped
# (\" and \n stay as written), which is all the routing patterns need.
prompt_text() {
  printf '%s' "$payload" | tr '\n\r' '  ' \
    | sed -n -E 's/.*"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# project_dir: where the session works.
project_dir() {
  local d="${CLAUDE_PROJECT_DIR:-}"
  [ -n "$d" ] || d="$(field cwd)"
  [ -n "$d" ] || d="$PWD"
  printf '%s' "$d"
}

# in_workspace DIR: DIR is Alis Build work: under an ~/alis.build workspace,
# or a Go module that depends on Alis-defined packages (a cloud session's
# checkout lives elsewhere).
in_workspace() {
  case "$1" in */alis.build/*|*/alis.build) return 0 ;; esac
  [ -f "$1/go.mod" ] && grep -qs 'alis\.build/' "$1/go.mod"
}

has_cli() { command -v alis >/dev/null 2>&1; }

# cli_plugin_enabled: the alis CLI's own plugin (alis@alis) is enabled for
# this project. It injects the CLI primer, routes wake words and warns about
# secrets itself, so this plugin steps aside for those jobs and keeps only
# what concerns its MCP server. The most specific settings file that names
# the plugin decides, as Claude Code's own precedence does.
cli_plugin_enabled() {
  local proj f
  proj="$(project_dir)"
  for f in "$proj/.claude/settings.local.json" "$proj/.claude/settings.json" \
           "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; do
    [ -f "$f" ] || continue
    grep -qE '"alis@alis"[[:space:]]*:[[:space:]]*true' "$f" && return 0
    grep -qE '"alis@alis"[[:space:]]*:[[:space:]]*false' "$f" && return 1
  done
  return 1
}

# state_dir: per-install scratch state that survives plugin updates.
state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/alisx-$(id -u 2>/dev/null || echo 0)}"
  mkdir -p "$d" 2>/dev/null && printf '%s' "$d"
}

# session_file NAME: a file for this session's state, or nothing when the
# session id is missing or not id-shaped.
session_file() {
  local sid d
  sid="$(field session_id)"
  [[ $sid =~ ^[A-Za-z0-9_-]{1,128}$ ]] || return 1
  d="$(state_dir)" || return 1
  mkdir -p "$d/sessions" 2>/dev/null || return 1
  printf '%s/sessions/%s.%s' "$d" "$sid" "$1"
}

# ---------------------------------------------------------------------------
# Secrets
#
# secret_hits TEXT prints one "kind<TAB>value" line per secret-looking value
# in TEXT, which may be JSON-escaped, from secret-patterns.tsv less the
# stand-ins in secret-placeholders.txt. The values are only ever hashed for
# de-duplication; no hook prints one. The caller sets hook_dir.

secret_hits() {
  local text=$1 kind pattern value
  [ -n "$text" ] || return 0
  while IFS='	' read -r kind pattern; do
    case $kind in ''|'#'*) continue ;; esac
    grep -oE -e "$pattern" <<< "$text" | grep -vE -f "$hook_dir/secret-placeholders.txt" \
      | while IFS= read -r value; do printf '%s\t%s\n' "$kind" "$value"; done
  done < "$hook_dir/secret-patterns.tsv"
}
