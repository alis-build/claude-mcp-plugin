#!/usr/bin/env bash
# Behaviour tests for the AlisX hooks: each hook is fed a recorded-shape event
# on stdin in a throwaway HOME, and its answer is checked. No network, no
# Claude Code, no alis CLI (a stub stands in where one is needed).
#
#   tests/hooks-test.sh
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$repo/plugins/alisx-hooks"
hooks="$plugin/hooks"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/alisx-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

command -v jq >/dev/null || { echo "jq is needed to check the hooks' JSON (the hooks themselves do not use it)" >&2; exit 2; }

pass=0 fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '  got: %s\n' "$2" >&2; }

# A machine without the alis CLI: only the system's own tools on PATH.
nocli="$tmp/nocli-bin"; mkdir -p "$nocli"
for t in bash sh cat grep sed tr head cut awk paste find rm mkdir id cksum dirname basename env printf; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$nocli/$t"
done
# A machine with it: the same, plus a stub that answers nothing.
withcli="$tmp/cli-bin"; mkdir -p "$withcli"
cp -P "$nocli"/* "$withcli"/
printf '#!/bin/sh\nexit 0\n' > "$withcli/alis"; chmod +x "$withcli/alis"

# run HOOK PATH_DIR PROJECT_DIR [VAR=value...] < event
# As hooks.json runs it: bash "${CLAUDE_PLUGIN_ROOT}/hooks/<hook>".
run() {
  local hook="$1" bin="$2" proj="$3"; shift 3
  env -i HOME="$tmp/home" PATH="$bin" CLAUDE_PLUGIN_ROOT="$plugin" \
    CLAUDE_PLUGIN_DATA="$tmp/data" CLAUDE_PROJECT_DIR="$proj" "$@" bash "$hooks/$hook"
}
ctx()     { jq -r '.hookSpecificOutput.additionalContext // empty'; }
decides() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }

expect_contains() {  # NAME HAYSTACK NEEDLE
  case "$2" in *"$3"*) ok ;; *) bad "$1: expected to contain [$3]" "$(printf '%s' "$2" | head -c 300)" ;; esac
}
expect_absent() {    # NAME HAYSTACK NEEDLE
  case "$2" in *"$3"*) bad "$1: expected not to contain [$3]" "$(printf '%s' "$2" | head -c 300)" ;; *) ok ;; esac
}
expect_eq() {        # NAME GOT WANT
  [ "$2" = "$3" ] && ok || bad "$1: expected [$3]" "$2"
}

mkdir -p "$tmp/home/.claude" "$tmp/plain"
ws="$tmp/alis.build/acme"
mkdir -p "$ws/build/shop/orders/v1/internal" "$ws/define/acme/shop/orders/v1" "$ws/define/acme/shop/billing/v2"
touch "$ws/define/acme/shop/orders/v1/orders.proto" "$ws/define/acme/shop/orders/v1/events.proto"
mkdir -p "$tmp/gomod"; printf 'module example.com/x\n\nrequire alis.build/acme/shop/orders/v1 v1.2.3\n' > "$tmp/gomod/go.mod"

start() { printf '{"session_id":"s1","hook_event_name":"SessionStart","source":"%s"}' "$1"; }

# --- SessionStart ----------------------------------------------------------

out="$(start startup | run session-start.sh "$nocli" "$tmp/plain")"
c="$(printf '%s' "$out" | ctx)"
expect_contains "plain folder gets the digest" "$c" "# Alis Build — refresher"
expect_absent   "plain folder: not the full primer" "$c" "## Define — lock"
expect_contains "no CLI: says what to do without it" "$c" "The alis CLI is not on this machine"
expect_absent   "no CLI: no notice" "$out" "systemMessage"

c="$(start startup | run session-start.sh "$nocli" "$ws/build/shop/orders/v1/internal" | ctx)"
expect_contains "workspace gets the full primer" "$c" "## Define — lock"
expect_contains "build side names the package" "$c" "Package ID:  acme.shop.orders.v1"
expect_contains "build side points at the contract" "$c" "$ws/define/acme/shop/orders/v1"
expect_contains "build side lists the protos" "$c" "events.proto, orders.proto"

c="$(start startup | run session-start.sh "$nocli" "$ws/define/acme/shop/billing/v2" | ctx)"
expect_contains "define side says so" "$c" "definitions (define) directory"
expect_contains "define side without build" "$c" "no build/ implementation directory yet"
expect_contains "define side package" "$c" "acme.shop.billing.v2"

c="$(start startup | run session-start.sh "$nocli" "$tmp/gomod" | ctx)"
expect_contains "a Go module on Alis packages is a workspace" "$c" "## Define — lock"

c="$(start compact | run session-start.sh "$nocli" "$ws/build/shop/orders/v1" | ctx)"
expect_contains "compact gets the digest" "$c" "refresher"
expect_contains "compact keeps the service pointer" "$c" "acme.shop.orders.v1"

c="$(start startup | run session-start.sh "$nocli" "$tmp/plain" ALIS_PRIMER=full | ctx)"
expect_contains "ALIS_PRIMER=full" "$c" "## Define — lock"
out="$(start startup | run session-start.sh "$nocli" "$tmp/plain" ALIS_PRIMER=off)"
expect_eq "ALIS_PRIMER=off outside a service says nothing" "$out" ""

out="$(start startup | run session-start.sh "$withcli" "$tmp/plain")"
expect_contains "CLI: its commands" "$(printf '%s' "$out" | ctx)" "The alis CLI is on this machine:"
expect_contains "CLI without its plugin: one notice" "$(printf '%s' "$out" | jq -r '.systemMessage // empty')" "claude plugin install alis@alis"
out="$(start startup | run session-start.sh "$withcli" "$tmp/plain")"
expect_absent "the notice is said once per install" "$out" "systemMessage"

c="$(start startup | run session-start.sh "$nocli" "$tmp/plain")"
[ "${#c}" -lt 10000 ] && ok || bad "context must stay under Claude Code's 10,000-character cap" "${#c}"
c="$(start startup | run session-start.sh "$withcli" "$ws/build/shop/orders/v1")"
c="$(printf '%s' "$c" | ctx)"
[ "${#c}" -lt 10000 ] && ok || bad "full primer + CLI + service must stay under 10,000 characters" "${#c}"

# The CLI's plugin enabled: step aside.
printf '{"enabledPlugins":{"alis@alis":true}}' > "$tmp/home/.claude/settings.json"
c="$(start startup | run session-start.sh "$withcli" "$ws/build/shop/orders/v1" | ctx)"
expect_contains "with alis@alis: a short note" "$c" "also connected"
expect_absent   "with alis@alis: no primer of its own" "$c" "## Define — lock"
mkdir -p "$tmp/plain/.claude"; printf '{"enabledPlugins":{"alis@alis":false}}' > "$tmp/plain/.claude/settings.json"
c="$(start startup | run session-start.sh "$nocli" "$tmp/plain" | ctx)"
expect_contains "project settings that disable alis@alis win" "$c" "refresher"
rm -f "$tmp/home/.claude/settings.json" "$tmp/plain/.claude/settings.json"

# --- UserPromptSubmit ------------------------------------------------------

prompt() {  # prompt TEXT [MODE] -> the hook's context
  local p; p="$(printf '%s' "$1" | jq -Rs .)"
  printf '{"session_id":"s1","hook_event_name":"UserPromptSubmit","permission_mode":"%s","prompt":%s}' "${2:-default}" "$p" \
    | run route-prompt.sh "$nocli" "$tmp/plain" | ctx
}
expect_contains "wake: 'alis, …'" "$(prompt 'alis, add a table for invoices')" "alisx:discover"
expect_contains "wake: 'Hey Alis …'" "$(prompt 'Hey Alis, how do I deploy?')" "alisx:discover"
expect_contains "wake: 'ask alis to …'" "$(prompt 'can you ask alis to set up pubsub')" "alisx:discover"
expect_eq       "mention is not a wake word" "$(prompt 'note the alis cli provides more than the mcp')" ""
expect_eq       "a word that starts with alis is not one" "$(prompt 'alisa, how are you')" ""
expect_contains "capture" "$(prompt 'great, capture this as a skill')" "alisx:capture"
expect_contains "capture: make that into a team skill" "$(prompt 'Make that into a team skill please')" "alisx:capture"
expect_contains "capture: skillify" "$(prompt 'skillify this')" "alisx:capture"
expect_contains "ticket" "$(prompt 'see tickets/AbC123 for context')" "tickets/AbC123"
expect_eq       "no ticket inside a path" "$(prompt 'open src/tickets/foo.go')" ""
expect_eq       "plain prompt: nothing" "$(prompt 'fix the failing unit test')" ""
expect_contains "plan mode on platform work" "$(prompt 'plan the spanner schema change' plan)" "search_skills once"
expect_eq       "plan mode on generic work" "$(prompt 'plan a refactor of the parser' plan)" ""
c="$(printf '{"prompt":"look at ideas/xyz789 first"}' | run route-prompt.sh "$withcli" "$tmp/plain" | ctx)"
expect_contains "ideas with the CLI" "$c" "alis ideate context xyz789"
expect_eq       "ideas without the CLI" "$(prompt 'look at ideas/xyz789 first')" ""
c="$(printf '{"prompt":"say \\"hi\\"\\nalis, deploy"}' | run route-prompt.sh "$nocli" "$tmp/plain" | ctx)"
expect_eq       "escaped quotes do not end the prompt early; wake only at the start" "$c" ""
printf '{"enabledPlugins":{"alis@alis":true}}' > "$tmp/home/.claude/settings.json"
expect_eq       "with alis@alis: routing steps aside" "$(prompt 'alis, add a table')" ""
rm -f "$tmp/home/.claude/settings.json"

# --- PreToolUse gate -------------------------------------------------------

gate() {  # gate TOOL INPUT_JSON [SERVER_PREFIX] -> the whole answer
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"%s%s","tool_input":%s,"tool_use_id":"t1"}' "${3:-mcp__plugin_alisx_alis__}" "$1" "$2" \
    | run gate-tools.sh "$nocli" "$tmp/plain"
}
while IFS= read -r t; do
  case "$t" in ''|'#'*) continue ;; esac
  a="$(gate "$t" '{}')"
  d="$(printf '%s' "$a" | decides)"
  case "$d" in ask|"") ok ;; *) bad "gate answers $t with ask or nothing" "$a" ;; esac
  [ -z "$a" ] || printf '%s' "$a" | jq -e . >/dev/null 2>&1 && ok || bad "gate answers $t with valid JSON" "$a"
done < "$repo/tests/fixtures/mcp-tools.txt"
expect_eq "read: search_skills keeps Claude's handling" "$(gate search_skills '{"query":"deploy a service"}')" ""
expect_eq "read: wait_for_reply keeps Claude's handling" "$(gate wait_for_reply '{"conversation":"tickets/1"}')" ""
expect_eq "destructive: delete_skill asks" "$(gate delete_skill '{"skill":"x"}' | decides)" ask
expect_eq "destructive: update_skill asks" "$(gate update_skill '{"skill":"x","summary":"y"}' | decides)" ask
expect_eq "destructive under another host's server name asks" "$(gate delete_skill '{"skill":"x"}' mcp__Alis_Build__ | decides)" ask
expect_eq "write: send_message keeps Claude's handling" "$(gate send_message '{"conversation":"tickets/1","message":"hi"}')" ""
expect_eq "unknown future write: no answer" "$(gate create_build '{"package":"a.b.c.v1"}')" ""
expect_eq "future read: no answer" "$(gate list_operations '{}')" ""
expect_eq "future deploy: asks" "$(gate deploy_version '{"version":"1.2.3"}' | decides)" ask
expect_eq "future secret read: asks" "$(gate list_environment_secrets '{}' | decides)" ask
expect_eq "future tools on another server: no answer" "$(gate deploy_version '{}' mcp__other__)" ""
expect_eq "production flag asks even on a read" "$(gate get_deployment '{"confirm_production":true}' | decides)" ask
expect_eq "reveal asks" "$(gate list_environment_variables '{"reveal": true}' | decides)" ask
expect_eq "reveal false: no answer" "$(gate list_environment_variables '{"reveal":false}')" ""
expect_eq "force asks" "$(gate update_build '{"force":true}' | decides)" ask
a="$(gate start_conversation '{"message":"my key is AKIAQWERTYUIOPASDFGHJ ok"}')"
expect_eq "a secret in the arguments is refused" "$(printf '%s' "$a" | decides)" deny
expect_absent "the refusal never repeats the value" "$a" "AKIAQWERTYUIOPASDFGHJ"
expect_eq "a secret is refused under another host's name too" "$(gate send_message '{"message":"ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' mcp__Alis_Build__ | decides)" deny
expect_eq "an example key is not a secret" "$(gate send_message '{"message":"e.g. AKIAIOSFODNN7EXAMPLE"}')" ""
out="$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | run gate-tools.sh "$nocli" "$tmp/plain")"
expect_eq "other tools are not gated" "$out" ""
# What the directory reads: the gate never answers allow, and prints no
# generated JSON.
gate_src="$(cat "$hooks/gate-tools.sh")"
expect_absent "the gate never allows" "$gate_src" '"allow"'
expect_absent "the gate uses no printf" "$gate_src" "printf"
expect_absent "the gate sources nothing" "$(grep -E '^[[:space:]]*(\.|source)[[:space:]]' "$hooks/gate-tools.sh")" "lib.sh"

# The matcher in hooks.json picks the same calls the gate reads.
matcher="$(jq -r '.hooks.PreToolUse[0].matcher' "$plugin/hooks/hooks.json")"
for name in mcp__plugin_alisx_alis__delete_skill mcp__plugin_alisx_alis__deploy_version mcp__Alis_Build__send_message; do
  node -e 'process.exit(new RegExp(process.argv[1]).test(process.argv[2]) ? 0 : 1)' "$matcher" "$name" 2>/dev/null && ok || bad "matcher picks $name"
done
for name in mcp__other__deploy_version Bash mcp__plugin_alisx_alis_; do
  node -e 'process.exit(new RegExp(process.argv[1]).test(process.argv[2]) ? 0 : 1)' "$matcher" "$name" 2>/dev/null && bad "matcher skips $name" || ok
done

# --- PostToolUse: secrets --------------------------------------------------

post() {  # post SESSION TOOL INPUT_JSON RESPONSE_JSON
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"%s","tool_input":%s,"tool_response":%s}' "$1" "$2" "$3" "$4" \
    | run warn-secrets.sh "$nocli" "$tmp/plain"
}
gh="ghp_$(printf 'a%.0s' $(seq 1 36))"
out="$(post s2 Bash '{"command":"cat .env"}' "{\"stdout\":\"GITHUB_TOKEN=$gh\\nDB_PASSWORD=hunter2hunter2\\nDATABASE_URL=postgres://app:s3cretpass@db.internal:5432/x\"}")"
c="$(printf '%s' "$out" | ctx)"
expect_contains "warns about a GitHub token" "$c" "GitHub token"
expect_contains "warns about an assignment" "$c" "secret assignment"
expect_contains "warns about a connection string" "$c" "connection string password"
expect_contains "the person is told" "$(printf '%s' "$out" | jq -r .systemMessage)" "may need rotating"
expect_absent "never repeats the token" "$out" "$gh"
expect_absent "never repeats the password" "$out" "hunter2hunter2"
out="$(post s2 Bash '{"command":"cat .env"}' "{\"stdout\":\"GITHUB_TOKEN=$gh\"}")"
expect_eq "each value once per session" "$out" ""
out="$(post s3 Read '{"file_path":"k.pem"}' '{"file":{"content":"-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAx7Zq9yX2bW4kL8\n-----END RSA PRIVATE KEY-----"}}')"
expect_contains "private key" "$(printf '%s' "$out" | ctx)" "private key"
expect_eq "placeholders are not secrets" "$(post s4 Bash '{}' '{"stdout":"API_TOKEN=${API_TOKEN}\nPASSWORD=<your-password>\npostgres://user:password@localhost"}')" ""
expect_eq "plain output: nothing" "$(post s4 Bash '{}' '{"stdout":"total 0\nok"}')" ""
out="$(printf '{"session_id":"s5","tool_name":"Bash","tool_input":{},"tool_response":{"stdout":"AKIAQWERTYUIOPASDFGHJ"}}' | run warn-secrets.sh "$nocli" "$tmp/plain" ALISX_SECRETS=off)"
expect_eq "ALISX_SECRETS=off" "$out" ""

# --- PostToolUse: a skill in use -------------------------------------------

load() {  # load SESSION INPUT_JSON [RESPONSE_JSON]
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"mcp__plugin_alisx_alis__load_skill","tool_input":%s,"tool_response":%s}' "$1" "$2" "${3:-[]}" \
    | run note-skill.sh "$nocli" "$tmp/plain"
}
c="$(load s6 '{"skill":"deploy-cloud-run"}' | ctx)"
expect_contains "a loaded skill asks for feedback later" "$c" "send_skill_feedback"
expect_contains "names the skill" "$c" "deploy-cloud-run"
expect_eq "once per skill per session" "$(load s6 '{"skill":"deploy-cloud-run"}')" ""
expect_eq "a continued read is the same skill" "$(load s7 '{"skill":"x-y","offset":12000}')" ""
expect_eq "a refused load is not in use" "$(load s8 '{"skill":"nope"}' '{"isError":true}')" ""

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
