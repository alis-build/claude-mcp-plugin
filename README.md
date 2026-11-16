# AlisX plugins for Claude

Two plugins that connect Claude to Alis Build through its MCP server at
`https://mcp.alisx.com`. They mirror the `alis` CLI's own plugin
([alis-build/claude-plugin](https://github.com/alis-build/claude-plugin)), with the MCP
server in place of the CLI.

| Plugin | What it is | Where it is published |
| --- | --- | --- |
| [`alisx`](plugins/alisx/README.md) | The MCP server, the skills `dbd`, `discover`, `capture`, `specialist`, and four commands. No hooks or scripts, so it works in Chat, Cowork and Claude Code alike | The Claude plugin directory, and this marketplace |
| [`alisx-hooks`](plugins/alisx-hooks/README.md) | Claude Code hooks: session primer and service context, wake-word routing, a gate on destructive calls and secrets, secret warnings, skill feedback. Depends on `alisx` | This marketplace only: the directory accepts hooks only from Verified organizations |

```text
/plugin install alisx --marketplace alis-build/claude-mcp-plugin
```

```sh
claude plugin marketplace add alis-build/claude-mcp-plugin
claude plugin install alisx-hooks@alisx   # also installs alisx
```

Once AlisX is a Verified organization, the hooks can move back into `alisx`.

## How it mirrors the CLI plugin

| `alis@alis` (CLI plugin) | AlisX |
| --- | --- |
| `load-primer.sh`: DBD primer in a workspace, digest elsewhere | `alisx:dbd` skill (everywhere); `alisx-hooks` injects it at session start with the same gating |
| `inject-service-context.sh`: package id and counterpart folder | `alisx-hooks` `session-start.sh`, same layout rules; the `dbd` skill states the rules too |
| `check-cli.sh`: one startup notice when the CLI needs upgrading | one notice per install when the CLI is present without its plugin |
| `suggest-skills.sh`: wake words and Skill store match through `alis skills suggest --hook` | `alisx:discover` triggers on the wake words; `alisx-hooks` `route-prompt.sh` routes them, capture phrases, `tickets/<id>` and plan mode (local matching only, see below) |
| `allow-alis-cli.sh`: permission gate for `alis …` Bash commands | `alisx-hooks` `gate-tools.sh`: asks before destructive MCP calls and refuses ones carrying secrets; it never grants a call, which the directory would hold |
| `warn-secrets.sh`: secret warnings after each tool call | `alisx-hooks` `warn-secrets.sh`, the same kinds in bash; the skills say never to send a secret |
| `report-skill-load.sh` and the module's "how did it go" line | `alisx:discover` asks once after a loaded skill's work; `alisx-hooks` `note-skill.sh` reminds Claude |
| skills `discover`, `capture` (via `alis skills …`) | skills `discover`, `capture` (via the MCP tools), plus `dbd` and `specialist` |
| `/alis share`, `/alis feedback`, `/alis status` (function-hooks module) | `/alisx:share`, `/alisx:feedback`, `/alisx:status`, `/alisx:conversations` (commands) |
| `sync-skills.sh`, handoff, `frontend-preview`, ops panes | not carried over: they drive the local CLI or terminal UI |

When the CLI plugin is enabled too, `alisx-hooks` steps aside for the primer, routing
and secret warnings, and keeps its gate.

**Per-prompt Skill store matching.** The CLI plugin searches the Skill store for every
prompt. Claude Code's `mcp_tool` hook type could do the same through this server. That
needs a server tool that answers nothing below a confident match: today's
`search_skills` always returns its closest results, which would add noise to every prompt.

## Repository layout

| Path | What lives there |
| --- | --- |
| `.claude-plugin/marketplace.json` | The `alisx` marketplace, with both plugins |
| `plugins/alisx/` | The directory plugin: `.mcp.json`, `skills/`, `commands/`, `assets/icon.png` |
| `plugins/alisx-hooks/hooks/` | `hooks.json`, the bash hooks, `lib.sh`, the secret patterns (data) |
| `plugins/alisx-hooks/context/` | `primer.md` (a copy of the `dbd` skill) and `digest.md` |
| `tests/` | `hooks-test.sh`, `release-guard.sh`, `fixtures/mcp-tools.txt` |
| `scripts/sync-tools.sh` | Refreshes the tool list from the server's source |
| `scripts/sync-primer.sh` | Copies the `dbd` skill to the hooks plugin's primer |

The directory scans only `plugins/alisx`. The release guard keeps it to what the
directory accepts from an organization that is not Verified: Markdown, text, JSON,
YAML and images, nothing starting with `#!`, and no hooks.

## When the MCP server gains tools

The server ([alis.os.mcp.v1](https://github.com/alis-build/alis), `os/mcp/v1`) is
growing towards everything the CLI does. Its new tools reach Claude without a plugin
release. Until the gate names them, Claude Code's own name for them falls back to
name rules (deploy, delete, secrets: ask). To name them:

1. `scripts/sync-tools.sh [path/to/os/mcp/v1]` refreshes `tests/fixtures/mcp-tools.txt`
   from the server's `scopes` map.
2. Add each new tool to the `case` in `plugins/alisx-hooks/hooks/gate-tools.sh` (step 3:
   no answer for reads and ordinary writes; a literal `ask` line for what the server
   marks destructive or what touches production or secrets). Also add it to the
   PreToolUse matcher in `hooks.json`, which picks the tool under any host's server name.
   The release guard fails until every tool is in both. Keep the gate's answers literal
   `echo` lines with no `printf`, no sourced files and never `allow`.
3. When a tool replaces a CLI step, update `plugins/alisx/skills/dbd/SKILL.md` and the
   other skills so that Claude prefers it, then run `scripts/sync-primer.sh`.

## Development checks

```sh
tests/release-guard.sh   # manifests, directory file rules, icon, hooks, tool names, primer copy
tests/hooks-test.sh      # every hook against recorded-shape events, in a throwaway HOME
```

Both need `bash` and `jq` (the hooks themselves need neither `jq` nor Python). With
Claude Code installed, the guard also runs `claude plugin validate`. To try the plugins
live without installing them:

```sh
claude --plugin-dir "$PWD/plugins/alisx" --plugin-dir "$PWD/plugins/alisx-hooks"
```

Then run `/mcp` to sign in, and `/alisx:status`.

For each release, bump `version` in the plugin's manifest and its marketplace entry, and
add a `CHANGELOG.md` entry.

## License

[MIT](LICENSE)
