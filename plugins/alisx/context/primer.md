# Alis Build — Define, Build, Deploy (DBD)

This session is connected to Alis Build through the AlisX plugin's MCP server
(`plugin:alisx:alis`, https://mcp.alisx.com), signed in as the person. Its tools are
the platform's own: today the Skill store and the person's conversations with Alis
Build specialists, with more of what the `alis` CLI does being added. Prefer an MCP
tool when one covers a step, and check the tool list before saying something cannot
be done.

The core workflow is **Define, Build, Deploy**. Frame Alis Build work in those steps
and walk the person through them rather than handing over a disconnected checklist.

## Define — lock the API / platform contract

- Protobuf contracts live in the build environment's define repo:
  `~/alis.build/<org>/define`.
- Commit and push, then Define: the contract pins to that pushed commit and generates
  language packages, and may sync platform artifacts such as Spanner protobundles or
  Pub/Sub topics. This is the source-of-truth step.

## Build — implement the service

- Product build repos: `~/alis.build/<org>/build/<product>`. Install or update the
  packages Define generated, then write the business logic (usually Go) against the
  generated stubs and typed APIs; never proto reflection. Stale-looking types mean
  the packages need updating.
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
- A production change needs the person's explicit approval every time. A session's
  permission mode grants nothing, and a refusal means stop: never retry, reword or
  work around it.

## Skills — find one before platform work

Skills are instructions for a kind of Alis Build work, written and kept current by
the people who do it. For platform-shaped work (a product, service, code block or
build environment; .proto contracts and Define; Spanner, Pub/Sub, Terraform under
`infra/`, packages, playground tests, ADK agents; sharing a page as a link) use the
`alisx:discover` skill: `search_skills`, then `load_skill` when a description clearly
fits; the loaded skill owns execution. Generic coding (Makefiles, ordinary bugs,
tests, git, reading logs) needs no search, even inside a workspace. Tell a skill's
owner how it did with `send_skill_feedback`. After solving something new by hand,
the person can say "capture this as a skill" (`alisx:capture`).

## Specialists — people, through conversations

- A referenced conversation (`tickets/<id>`, or a subject) is read before proposing
  changes: `get_conversation`, or `search_conversations` to find it. Ask which one
  when several match.
- Before starting one, check `list_conversations` and carry on an open conversation
  on the same subject. Put the whole problem in the first message: what was wanted,
  what was tried, error text word for word. Send only what the person asked to send.
- A specialist is a person and may take hours. `wait_for_reply` waits a few minutes;
  when it answers `waiting`, say so and come back later instead of looping.
- A platform-side failure (such as a platform-injected credential error like
  `invalid_grant`) is not fixable in the repo: report it and offer to raise it with a
  specialist (`alisx:specialist`).

## Signing in

When an Alis tool is missing or says it needs authentication: in Claude Code, run
`/mcp`, choose `plugin:alisx:alis` and Authenticate; in the Claude app, open
Customize → Connectors and connect Alis Build. Then try again.
