# Changelog

## [0.1.0] - 2026-11-16

First release for the Claude plugin directory.

- The Alis Build MCP server (`https://mcp.alisx.com`, `plugin:alisx:alis`): Skill store and
  specialist conversations, signed in with Alis's identity service.
- Hooks mirroring the `alis` CLI plugin: session primer and service context, wake-word and
  capture routing, a permission gate for the server's tools (`tool-policy.tsv`), secret
  warnings, and skill feedback prompts. Bash only; no network calls.
- Skills `discover`, `capture`, `specialist`; commands `/alisx:status`,
  `/alisx:conversations`, `/alisx:share`, `/alisx:feedback`.
- Steps aside for the primer, routing and secret warnings when the CLI plugin (`alis@alis`)
  is enabled.
