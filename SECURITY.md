# Security policy

## Reporting a vulnerability

**Please don't open a public issue for a security problem.** Report it privately through
GitHub: [report a vulnerability](https://github.com/alis-build/claude-mcp-plugin/security/advisories/new).

Include what you found, how to reproduce it, and the plugin and Claude versions you used.
Leave out real secrets: a made-up value that shows the problem is enough.

## Supported versions

Only the latest release gets security fixes. Update with `claude plugin marketplace update alisx`.

## What counts

In scope, for this plugin:

- A way past the permission gate: a destructive Alis tool call, or one asking for production
  or a reveal, that runs without asking.
- A secret that reaches the MCP server, a warning or the person's screen when the plugin
  should have refused or withheld it.
- A hook that sends data anywhere, or runs code or reads files it shouldn't.

Out of scope here: the Alis Build MCP server, the platform and Claude itself. Report those
to their owners ([Alis Build support](https://console.alisx.com/support) for the platform).
