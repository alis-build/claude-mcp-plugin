# Changelog

## [0.2.1] - 2026-11-16

- Every skill and command works in Claude Chat, which has no files or shell: `alisx:dbd`
  works from what the person says or pastes, gives CLI steps as commands for the person to run,
  and checks files on disk only where the session can see them; `/alisx:status` checks only
  the connection, the Skill store and conversations; commands no longer depend on `$ARGUMENTS`
  being filled in.

## [0.2.0] - 2026-11-16

The plugin directory accepts hooks and scripts only from Verified organizations, so the
plugin is split in two.

- `alisx` (the directory plugin) now ships only the MCP server, skills, commands and a
  PNG icon: no hooks, no scripts, no SVG.
- New skill `alisx:dbd`: the Define, Build, Deploy primer, the workspace layout and package
  ids, the steps that still need the `alis` CLI, and what never happens without the person
  (production, destructive skill changes, sending secrets). `alisx:discover` now asks once
  after a loaded skill's work whether it helped.
- New plugin `alisx-hooks` (this marketplace only, depends on `alisx`): the hooks from 0.1.1.
  Its session start injects a copy of the `dbd` skill (`scripts/sync-primer.sh`) and states
  whether the CLI is installed.

## [0.1.1] - 2026-11-16

Changes from the plugin directory's first review.

- The permission gate never grants a call any more: it only asks (destructive writes,
  production, reveal, force) or refuses (secrets). Reads keep Claude's normal permission
  prompt. Its answers are literal JSON lines in one self-contained script, so the directory
  can read everything it may say; `tool-policy.tsv` is folded into it.
- Alis tools are matched by the end of their name (`mcp__*__delete_skill`), so the gate and
  the skill feedback prompt also work where the host names the server differently (Cowork).
  Rules for tools the server adds later still apply only under Claude Code's name.
- Hooks name their interpreter (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/…"`). The secret patterns
  move to data files (`secret-patterns.tsv`, `secret-placeholders.txt`).

## [0.1.0] - 2026-11-16

First release for the Claude plugin directory.

- The Alis Build MCP server (`https://mcp.alisx.com`, `plugin:alisx:alis`): Skill store and
  specialist conversations, signed in with Alis's identity service.
- Hooks mirroring the `alis` CLI plugin: session primer and service context, wake-word and
  capture routing, a permission gate for the server's tools, secret
  warnings, and skill feedback prompts. Bash only; no network calls.
- Skills `discover`, `capture`, `specialist`; commands `/alisx:status`,
  `/alisx:conversations`, `/alisx:share`, `/alisx:feedback`.
- Steps aside for the primer, routing and secret warnings when the CLI plugin (`alis@alis`)
  is enabled.
