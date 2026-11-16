# AlisX hooks for Claude Code

Hooks that make Claude Code work better with Alis Build. This plugin is a companion to
the [`alisx`](../alisx/README.md) plugin, which brings the Alis Build MCP server and
skills; installing this one installs that one too. The hooks run in Claude Code (the
terminal, the desktop Code tab, the web) and Cowork; Chat does not run hooks.

This plugin is published only in this repository's marketplace, not in the Claude
plugin directory. The directory accepts hooks only from Verified organizations.

```sh
claude plugin marketplace add alis-build/claude-mcp-plugin
claude plugin install alisx-hooks@alisx
```

## What the hooks do

Every hook is a small bash script in `hooks/`, run as
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>.sh"`. None of them makes a network call;
the only data that leaves your machine goes through the MCP server's tools, which
Claude calls.

- **Session start** (`session-start.sh`): adds the Define, Build, Deploy primer to
  the session, a copy of the `alisx:dbd` skill. You get the full primer inside an
  `~/alis.build` workspace or a Go module that uses Alis packages, and a short
  digest elsewhere and after resume or compact. It also says whether the `alis` CLI is
  on this machine. Inside a `~/alis.build/<org>/build|define/…` service folder, it adds
  the package id and where the contract or implementation lives.
  `ALIS_PRIMER=full|digest|off` overrides the choice.
- **Prompt routing** (`route-prompt.sh`): a prompt that starts with "alis, …" or
  "hey alis", or says "ask alis to …", goes to `alisx:discover`. "Capture this as a
  skill" goes to `alisx:capture`. A `tickets/<id>` reference is read before anything
  is proposed. In plan mode on platform work, Claude searches the Skill store once.
  The matching is local, and other prompts get nothing.
- **Permission gate** (`gate-tools.sh`): this hook only ever asks you or refuses a
  call; it never grants one. Writes the server marks destructive (`update_skill`,
  `restore_skill_version`, `delete_skill`) always ask you, in every permission mode.
  So does any call whose arguments ask for production, a reveal or a forced change.
  A call whose arguments carry a secret-looking value is refused, so Claude takes the
  value out before anything is sent. A tool the server adds later asks you when its
  name says it deploys, removes or touches secrets. Everything else, reads included,
  keeps Claude's normal permission prompt.
- **Secret warnings** (`warn-secrets.sh`): after each tool call, the result and
  arguments are checked for secret-looking values (patterns in
  `hooks/secret-patterns.tsv`). These include Stripe, GitHub, npm, PyPI, Linear,
  SendGrid, AWS, Google, Slack, Anthropic and OpenAI keys, private keys, connection
  strings with passwords and `NAME=value` lines whose name says secret. Claude is told
  the kinds found and not to repeat them, and you see one line saying they may need
  rotating. Values never appear in either. A hash of each value is kept for a day in
  the plugin's data folder, so each is reported once per session. `ALISX_SECRETS=off`
  turns this off.
- **Skill feedback** (`note-skill.sh`): when a Skill store skill is loaded, Claude
  asks you once, after the work it guided, whether it helped, and sends your answer
  to its owner with `send_skill_feedback` only if you give one.

## With the `alis` CLI and its plugin

The `alis` CLI's own Claude Code plugin (`alis@alis`) runs Define, Build and Deploy
from the terminal. When it is enabled, these hooks step aside for the primer, routing
and secret warnings, and keep the permission gate. To tell whether it is enabled, they
read the `enabledPlugins` entry for `alis@alis` in your Claude settings files. If the
CLI is installed without its plugin, the first session says once how to add it.

## Kept locally

Under the plugin's data folder: the hashes of reported secrets and the ids of skills
already asked about (both removed after a day), and a marker that the CLI notice was
shown.
