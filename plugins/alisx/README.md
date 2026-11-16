# AlisX for Claude

Connect Claude to [Alis Build](https://alisx.com). The plugin adds the Alis Build MCP
server (`https://mcp.alisx.com`), signed in as you, so Claude can find and follow the
platform's skills and carry on your conversations with Alis Build specialists. It
also teaches Claude the Define, Build, Deploy workflow, routes "alis, …" requests to
the right skill, asks you before destructive Alis actions and warns when a secret
lands in the conversation.

The MCP server is growing to cover what the `alis` CLI does. Today it serves the
Skill store and specialist conversations (21 tools); new tools appear in the plugin
as soon as the server offers them, with no plugin update.

## Install

In Claude Code (terminal, desktop app or web):

```text
/plugin install alisx --marketplace alis-build/claude-mcp-plugin
```

or, step by step:

```sh
claude plugin marketplace add alis-build/claude-mcp-plugin
claude plugin install alisx@alisx
```

In the Claude app (Chat and Cowork), install AlisX from the plugin directory.

## Sign in

The first Alis tool call needs your Alis account. You sign in with Alis's own
identity service (`identity.alisx.com`) and approve what Claude may do: read and
write skills, and read and write your specialist conversations. Claude identifies
itself to Alis, so nothing needs setting up first.

- **Claude Code (terminal, desktop Code tab):** run `/mcp`, choose `plugin:alisx:alis`
  and Authenticate.
- **Claude Code on the web:** connect Alis Build at claude.ai, Customize → Connectors;
  web sessions use that sign-in.
- **Chat and Cowork:** open Customize → Connectors and connect Alis Build.

A sign-in lasts while you use it (it ends after seven days unused, or 90 days in
all). Disconnect it from the same menu.

## What you get

| | Chat | Cowork | Claude Code |
| --- | --- | --- | --- |
| The Alis Build MCP server (skills, conversations) | ✓ (Connectors) | ✓ | ✓ |
| Skills: `discover`, `capture`, `specialist` | ✓ | ✓ | ✓ |
| Commands: `/alisx:status`, `/alisx:conversations`, `/alisx:share`, `/alisx:feedback` | as skills | ✓ | ✓ |
| Hooks: context, routing, permission gate, secret warnings | — | ✓ | ✓ |

### Skills

- **`alisx:discover`** finds the right Skill store skill for platform-shaped work
  (services, `.proto` contracts and Define, Spanner, Pub/Sub, Terraform under `infra/`,
  packages, playground tests, ADK agents, sharing a page) with `search_skills`, loads it
  only when its description clearly fits, and lets it lead. Generic coding gets no
  search, and a miss is silent.
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

### Hooks (Claude Code and Cowork)

Every hook is a small bash script in `hooks/`. None of them makes a network call;
the only data that leaves your machine goes through the MCP server's tools, which
Claude calls (see below).

- **Session start** (`session-start.sh`): adds the Define, Build, Deploy primer to
  the session. You get the full primer inside an `~/alis.build` workspace or a Go
  module that uses Alis packages, and a short digest elsewhere and after
  resume or compact. It also says whether the `alis` CLI is on this machine.
  Inside a `~/alis.build/<org>/build|define/…` service folder, it adds the package id
  and where the contract or implementation lives. `ALIS_PRIMER=full|digest|off`
  overrides the choice.
- **Prompt routing** (`route-prompt.sh`): a prompt that starts with "alis, …" or
  "hey alis", or says "ask alis to …", goes to `alisx:discover`. "Capture this as a
  skill" goes to `alisx:capture`. A `tickets/<id>` reference is read before
  anything is proposed. In plan mode on platform work, Claude searches the Skill
  store once. The matching is local, and other prompts get nothing.
- **Permission gate** (`gate-tools.sh`, rules in `tool-policy.tsv`): the server makes
  every tool a read or a write. Reads (search, list, load, read and wait tools) run
  without a prompt. Writes the server marks destructive (`update_skill`,
  `restore_skill_version`, `delete_skill`) always ask you, in every permission mode.
  Other writes, such as sending a message or creating a skill, keep Claude's normal
  permission prompt. Any call whose arguments ask for production, a reveal or an
  override also asks. A call whose arguments carry a secret-looking value is refused,
  so Claude takes the value out before anything is sent. New server tools follow
  rules by name: reads run, anything that deploys, deletes or touches secrets asks,
  and the rest keeps Claude's normal prompt.
- **Secret warnings** (`warn-secrets.sh`): after each tool call, the result and
  arguments are checked for secret-looking values. These include Stripe, GitHub, npm,
  PyPI, Linear, SendGrid, AWS, Google, Slack, Anthropic and OpenAI keys, private keys,
  connection strings with passwords and `NAME=value` lines whose name says secret.
  Claude is told the kinds found and not to repeat them, and you see one line
  saying they may need rotating. Values never appear in either. A hash of each value
  is kept for a day in the plugin's data folder, so each is reported once per
  session. `ALISX_SECRETS=off` turns this off.
- **Skill feedback** (`note-skill.sh`): when a Skill store skill is loaded, Claude
  asks you once, after the work it guided, whether it helped, and sends your answer
  to its owner with `send_skill_feedback` only if you give one.

### With the `alis` CLI and its plugin

The `alis` CLI's own Claude Code plugin (`alis@alis`) runs Define, Build and Deploy
from the terminal. When it is enabled, AlisX steps aside for the primer, routing and
secret warnings, and keeps the MCP server and its permission gate. If the CLI is
installed without its plugin, the first session says once how to add it.

## Data and privacy

- **Sent to Alis Build:** what Claude passes to the MCP server's tools, signed in as
  you: search queries, skill ids, skill files you publish, feedback, and messages
  and files you send to specialists. Writes keep Claude's permission prompt or always
  ask, as above. Specialists read what you send them.
- **Not sent:** your prompts (the routing is local), files on disk, tool output and
  the session transcript. The hooks make no network calls.
- **Kept locally:** under the plugin's data folder, the hashes of reported secrets,
  the ids of skills already asked about (both removed after a day) and a marker that
  the CLI notice was shown.

Alis Build's [privacy policy](https://alisx.com/privacy-policy/) and
[terms of use](https://alisx.com/terms-of-use/) apply to the service.

## Troubleshooting

- **Alis tools missing, or asking to sign in:** sign in as above, then retry. In
  Claude Code, `/mcp` shows the server's state.
- **No primer or routing:** check that AlisX is enabled in `/plugin`. If you installed
  it during a session, run `/reload-plugins`. `ALIS_PRIMER=off` turns the primer off
  on purpose.
- **A step needs the `alis` CLI:** Define, Build and Deploy run through the CLI until
  the MCP server covers them. Without it, Claude names the step and the exact command
  instead of improvising one.
- Support: [console.alisx.com/support](https://console.alisx.com/support).
