# Alis Build — Define, Build, Deploy (DBD)

The AlisX plugin connects this session to Alis Build through its MCP server
(`https://mcp.alisx.com`), signed in as the person. Its tools are the platform's own:
today the Skill store and the person's conversations with Alis Build specialists,
with more of what the `alis` CLI does being added. Prefer an MCP tool when one covers
a step, and check the tool list before saying something cannot be done.

The core workflow is **Define, Build, Deploy**. Frame Alis Build work in those steps
and walk the person through them rather than handing over a disconnected checklist.

## Where the work is

Workspaces follow one layout:

- build (implementation): `~/alis.build/<org>/build/<product>/<service>/<vN>/…`
- define (contract): `~/alis.build/<org>/define/<org>/<product>/<service>/<vN>/…`
- the package id is `<org>.<product>.<service>.<vN>`, the path segments up to `vN`
  joined with dots (for example `acme.shop.orders.v1`).

When the session is inside one half, name the package id and point at the other half
(the `.proto` files on the define side, the implementation on the build side). Check
on disk; say so when the other half is missing.

## Define — lock the API / platform contract

- Protobuf contracts live in the build environment's define repo.
- Commit and push, then Define: the contract pins to that pushed commit and generates
  language packages, and may sync platform artifacts such as Spanner protobundles or
  Pub/Sub topics. This is the source-of-truth step.

## Build — implement the service

- Install or update the packages Define generated, then write the business logic
  (usually Go) against the generated stubs and typed APIs; never proto reflection.
  Stale-looking types mean the packages need updating.
- The Go import for package `<org>.<product>.<service>.<vN>` is
  `alis.build/<org>/<product>/<service>/<vN>`. A service still importing
  `internal.<product>.<org>.services/protobuf/...` is on the deprecated product-level
  package: never copy that shape; mention it and look for the migration skill.
- **Build runs from a pushed commit, never the working tree.** Commit and push first
  (source, Dockerfile, go.mod alike); when a rebuild fails identically, compare the
  commit hash in the build output with the fix before re-diagnosing.
- Never hand-edit dependency pins (`sed` on go.mod) or hand-assemble private registry
  settings: the platform's package tooling handles registries and credentials.

## Deploy — provision and update the runtime

- The runtime is the service's Terraform under `infra/`; the deployment environment
  comes from the product, never a guess.
- Validate end to end with the generated playground, usually
  `<neuron>/.playground/main_test.go` (hidden and git-ignored: search it with
  `rg --hidden --no-ignore`).

## Steps no MCP tool covers yet

Define, Build, Deploy, package installs and deployment environments run through the
`alis` CLI until the server covers them. If this session has a shell, check once
whether it is installed (`alis version`, as its own command).

- **With the CLI:** `alis docs` and `alis <cmd> --help` are its source of truth.
  Define: `alis define <pkg> --json --install`. Build:
  `alis build <pkg> --json --deploy -e <env> --async`. Deploy:
  `alis deploy <pkg> --version <version> -e <env> --json --async`. Packages:
  `alis packages install|upgrade|add <pkg> --json`. Environments:
  `alis environment list <org>.<product> --json`. One standalone `alis` command per
  call, `alis --cwd /absolute/path …` instead of `cd … &&`, no pipes or redirects;
  under `--json` stdout is one JSON object and stderr is progress. Never poll with
  `sleep`: `alis operations wait <op> --json`. Exit code 4 means signed out
  (`alis login`).
- **Without it:** do not improvise these steps with gcloud, curl, hand-written registry
  settings or Terraform applied by hand. Say which step remains and the exact `alis`
  command for it, and that the person can run it where the CLI is installed or ask a
  specialist. Code, contracts and infra changes can still be written here.

## Never without the person

- A production change needs the person's explicit approval every time
  (`--confirm-production`, or a tool argument that targets production). A permission
  mode grants nothing, and a refusal means stop: never retry, reword or work around it.
- Before `update_skill`, `restore_skill_version` or `delete_skill`, say what will
  change for everyone who uses the skill and wait for a yes in chat.
- Never send a secret (a key, token, password, private key, a connection string with
  a password) to an Alis tool: messages, files, feedback and skills are stored and
  read by people. Take it out or write `[REDACTED]`. If a secret shows up in this
  conversation, do not repeat it, and tell the person it may need rotating.

## Skills and specialists

- For the task at hand, `alisx:discover` finds the Skill store skill that covers it.
  Generic coding (Makefiles, ordinary bugs, tests, git, reading logs) needs none.
- A referenced conversation (`tickets/<id>`) is read with `get_conversation` before
  proposing changes; `alisx:specialist` asks a person for help. A platform-side failure
  (such as a platform-injected `invalid_grant`) is not fixable in the repo: report it
  and offer to raise it with a specialist.
- After solving something new by hand, the person can say "capture this as a skill"
  (`alisx:capture`).

## Signing in

When an Alis tool is missing or says it needs authentication: in Claude Code, run
`/mcp`, choose `plugin:alisx:alis` and Authenticate; in the Claude app, open
Customize → Connectors and connect Alis Build. Then try again.
