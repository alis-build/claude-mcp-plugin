# AlisX plugin for Claude

The Alis Build plugin for the Claude plugin directory. It connects Claude (Chat, Cowork,
and Claude Code in the terminal, the desktop app and on the web) to the Alis Build MCP
server at `https://mcp.alisx.com`, and adds the hooks, skills and commands that make
Claude work well with the platform. These mirror the `alis` CLI's own plugin
([alis-build/claude-plugin](https://github.com/alis-build/claude-plugin)), with the MCP
server in place of the CLI.

**What it does, how to install it and what it sends: [plugins/alisx/README.md](plugins/alisx/README.md).**

```text
/plugin install alisx --marketplace alis-build/claude-mcp-plugin
```

## How it mirrors the CLI plugin

| `alis@alis` (CLI plugin) | `alisx` (this plugin) |
| --- | --- |
| `load-primer.sh`: DBD primer in a workspace, digest elsewhere | `session-start.sh`: the same gating, MCP-first primer, plus what to do with or without the CLI |
| `inject-service-context.sh`: package id and counterpart folder | folded into `session-start.sh`, same layout rules |
| `check-cli.sh`: one startup notice when the CLI needs upgrading | one notice per install when the CLI is present without its plugin |
| `suggest-skills.sh`: wake words and Skill store match through `alis skills suggest --hook` | `route-prompt.sh`: wake words, capture phrases, `tickets/<id>`, plan mode; local matching only (see below) |
| `allow-alis-cli.sh`: permission gate for `alis …` Bash commands | `gate-tools.sh` + `tool-policy.tsv`: permission gate for the MCP server's tools |
| `warn-secrets.sh`: secret warnings after each tool call | `warn-secrets.sh`: the same kinds, in bash; also refuses secrets in calls to the MCP server |
| `report-skill-load.sh` and the module's "how did it go" line | `note-skill.sh`: asks once after a loaded skill's work, sends with `send_skill_feedback` |
| skills `discover`, `capture` (via `alis skills …`) | skills `discover`, `capture` (via the MCP tools), plus `specialist` |
| `/alis share`, `/alis feedback`, `/alis status` (function-hooks module) | `/alisx:share`, `/alisx:feedback`, `/alisx:status`, `/alisx:conversations` (commands) |
| `sync-skills.sh`, handoff, `frontend-preview`, ops panes | not carried over: they drive the local CLI or terminal UI |

When the CLI plugin is enabled too, this plugin steps aside for the primer, routing and
secret warnings, and keeps its MCP server and gate.

**Per-prompt Skill store matching.** The CLI plugin searches the Skill store for every
prompt. Claude Code's `mcp_tool` hook type could do the same through this server. That
needs a server tool that answers nothing below a confident match: today's
`search_skills` always returns its closest results, which would add noise to every prompt.

## Repository layout

| Path | What lives there |
| --- | --- |
| `.claude-plugin/marketplace.json` | The `alisx` marketplace, with the one plugin |
| `plugins/alisx/.claude-plugin/plugin.json` | The plugin manifest |
| `plugins/alisx/.mcp.json` | The Alis Build MCP server |
| `plugins/alisx/hooks/` | `hooks.json`, the bash hooks, `lib.sh`, `tool-policy.tsv` |
| `plugins/alisx/context/` | Primer, digest, and the CLI and no-CLI sections |
| `plugins/alisx/skills/`, `commands/` | Skills and slash commands |
| `tests/` | `hooks-test.sh`, `release-guard.sh`, `fixtures/mcp-tools.txt` |
| `scripts/sync-tools.sh` | Refreshes the tool list from the server's source |

## When the MCP server gains tools

The server ([alis.os.mcp.v1](https://github.com/alis-build/alis), `os/mcp/v1`) is
growing towards everything the CLI does. Its new tools reach Claude without a plugin
release, and the gate handles them by name until they get a rule. To give them one:

1. `scripts/sync-tools.sh [path/to/os/mcp/v1]` refreshes `tests/fixtures/mcp-tools.txt`
   from the server's `scopes` map.
2. Add a rule for each new tool to `plugins/alisx/hooks/tool-policy.tsv`, above the
   fallbacks: `allow` for reads, `ask` for what the server marks destructive or what
   touches production or secrets, `none` for other writes. The release guard fails until
   every tool has one.
3. When a tool replaces a CLI step, update `context/primer.md` and the skills so that
   Claude prefers it, and `context/no-cli.md` so the step is no longer listed as needing
   the CLI.

## Development checks

```sh
tests/release-guard.sh   # manifests, hooks, tool rules, Chat-safe front matter, directory checks
tests/hooks-test.sh      # every hook against recorded-shape events, in a throwaway HOME
```

Both need `bash` and `jq` (the hooks themselves need neither `jq` nor Python). With
Claude Code installed, the guard also runs `claude plugin validate --strict --profile
directory`. To try the plugin live without installing it:

```sh
claude --plugin-dir "$PWD/plugins/alisx"
```

Then run `/mcp` to sign in, and `/alisx:status`.

Bump `version` in both manifests and add a `CHANGELOG.md` entry for each release.

## License

[MIT](LICENSE)
