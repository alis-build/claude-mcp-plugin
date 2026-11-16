---
description: Show whether Alis Build is connected in this session, and which conversations are waiting on you.
---

Report the AlisX connection in a few short lines, without changing anything:

1. **Signed in?** Call `list_conversations` (open ones, `page_size` 10). If the Alis tools are
   missing or the call asks for authentication, say so and how to connect: in Claude Code,
   `/mcp` → `plugin:alisx:alis` → Authenticate; in the Claude app, Customize → Connectors →
   Alis Build. Stop there.
2. **Conversations:** how many are open, and name the ones whose turn is the person's (subject
   and id). Say "none waiting on you" when there are none.
3. **Workspace:** if the session started in an Alis Build service folder, its package id (from
   the session context).
4. **CLI:** only if this session has a shell, whether the `alis` CLI is on PATH (`alis version`
   as its own command; a missing command is the answer, not an error to fix). Define, Build and
   Deploy run through it until the MCP server covers them.

$ARGUMENTS
