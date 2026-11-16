# AlisX for Claude

Connect Claude to [Alis Build](https://alisx.com). The plugin adds the Alis Build MCP
server (`https://mcp.alisx.com`), signed in as you, so Claude can find and follow the
platform's skills and carry on your conversations with Alis Build specialists. Its
skills teach Claude the Define, Build, Deploy workflow, how to pick the right skill
for a task, how to save new work as a skill, and how to ask a specialist for help.

The MCP server is growing to cover what the `alis` CLI does. Today it serves the
Skill store and specialist conversations (21 tools); new tools appear in Claude as
soon as the server offers them, with no plugin update.

## Install

In the Claude app (Chat, Cowork, and the desktop Code tab), install AlisX from the
plugin directory. In Claude Code:

```text
/plugin install alisx --marketplace alis-build/claude-mcp-plugin
```

## Sign in

The first Alis tool call needs your Alis account. You sign in with Alis's own
identity service (`identity.alisx.com`) and approve what Claude may do: read and
write skills, and read and write your specialist conversations. Claude identifies
itself to Alis, so nothing needs setting up first.

- **Chat and Cowork:** open Customize → Connectors and connect Alis Build.
- **Claude Code (terminal, desktop Code tab):** run `/mcp`, choose `plugin:alisx:alis`
  and Authenticate.
- **Claude Code on the web:** connect Alis Build at claude.ai, Customize → Connectors;
  web sessions use that sign-in.

A sign-in lasts while you use it (it ends after seven days unused, or 90 days in
all). Disconnect it from the same menu.

## What you get

### Skills

- **`alisx:dbd`**: how Alis Build works. It covers Define, Build and Deploy, where
  contracts and services live and how a package id is formed. It also says which steps
  still need the `alis` CLI and what Claude never does without you: production changes,
  destructive skill changes, sending secrets.
- **`alisx:discover`** finds the right Skill store skill for platform-shaped work
  (services, `.proto` contracts and Define, Spanner, Pub/Sub, Terraform under `infra/`,
  packages, playground tests, ADK agents, sharing a page) with `search_skills`. It loads
  a skill only when its description clearly fits, then lets it lead. When the work is
  done, Claude asks you once whether the skill helped, and passes your answer to its
  owner. Generic coding gets no search, and a miss is silent.
- **`alisx:capture`**: say "capture this as a skill" after solving something new.
  Claude checks for an existing skill, agrees the id and scope with you once, drafts
  the files, shows you the outline and publishes with `create_skill` only when you
  say so.
- **`alisx:specialist`** reads a conversation you refer to (`tickets/<id>`), carries
  an open one on instead of starting a duplicate, and starts a new one with the whole
  problem: what you wanted, what was tried and the exact error. Claude shows you the
  message before sending unless you dictated it, and never waits on a reply in a loop.

### Commands

- `/alisx:status`: whether Alis Build is connected, and which conversations are
  waiting on you.
- `/alisx:conversations [search or tickets/<id>]`: your conversations and whose
  turn each is.
- `/alisx:share [note]`: raise this session with the AlisX build team. Claude
  writes a message a specialist can act on, shows you the subject, message and file
  names, and sends only when you say yes. The transcript itself is not attached.
- `/alisx:feedback [skill] <message>`: tell a skill's owner how it did.

In Chat, commands work as skills: Claude uses one when your request fits it.

### Claude Code hooks (optional, separate plugin)

The `alisx-hooks` plugin, from this plugin's GitHub marketplace, adds hooks for Claude
Code. It injects the `alisx:dbd` primer and the service you opened at session start,
and routes "alis, …" to `alisx:discover`. It also asks before destructive Alis Build
calls, refuses calls that carry a secret, and warns when a secret appears in a tool's
output. It is not part of this directory listing:

```sh
claude plugin marketplace add alis-build/claude-mcp-plugin
claude plugin install alisx-hooks@alisx
```

## Data and privacy

- **Sent to Alis Build:** what Claude passes to the MCP server's tools, signed in as
  you: search queries, skill ids, skill files you publish, feedback, and messages
  and files you send to specialists. Specialists read what you send them. Claude's
  normal permission prompts apply to each tool call.
- **Not sent:** your prompts, files on disk and the session transcript, except what
  Claude puts into a tool call. This plugin has no hooks or scripts; it runs nothing
  on your machine.

Alis Build's [privacy policy](https://alisx.com/privacy-policy/) and
[terms of use](https://alisx.com/terms-of-use/) apply to the service.

## Troubleshooting

- **Alis tools missing, or asking to sign in:** sign in as above, then retry. In
  Claude Code, `/mcp` shows the server's state.
- **A step needs the `alis` CLI:** Define, Build and Deploy run through the CLI until
  the MCP server covers them. Without it, Claude names the step and the exact command
  instead of improvising one.
- Support: [console.alisx.com/support](https://console.alisx.com/support).
