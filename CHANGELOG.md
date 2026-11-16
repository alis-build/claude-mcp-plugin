# Changelog

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
