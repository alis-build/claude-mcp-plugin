# Alis Build — refresher

The AlisX plugin connects this session to Alis Build's MCP server
(`plugin:alisx:alis`): the Skill store and the person's conversations with Alis Build
specialists, with tools for Define, Build and Deploy being added. Everything on the
platform happens through these tools. The full primer is the `alisx:dbd` skill: read it before
Alis Build work this session has not done yet.

Define, Build, Deploy: contracts in `~/alis.build/<org>/define` pin to a pushed
commit and generate packages; services in `~/alis.build/<org>/build/<product>` build
from the latest *pushed* commit; Deploy provisions from the service's `infra/`
Terraform. Never hand-edit dependency pins or registry settings. Production needs
the person's explicit approval every time, and a refusal means stop. Never send a
secret to an Alis tool.

For platform-shaped work, `alisx:discover` finds a skill (`search_skills`, then
`load_skill` only when a description clearly fits); generic coding needs none. Read
a referenced conversation (`tickets/<id>`) with `get_conversation` before proposing
changes; `alisx:specialist` asks a person for help. If an Alis tool needs sign-in:
`/mcp` → `plugin:alisx:alis` in Claude Code, or Customize → Connectors in the app.
