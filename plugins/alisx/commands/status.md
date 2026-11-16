---
description: Show whether Alis Build is connected, and which conversations are waiting on you.
---

Report the AlisX connection in a few short lines, without changing anything:

1. **Signed in?** Call `list_conversations` (open ones, `page_size` 10). If the Alis tools are
   missing or the call asks for authentication, say so and how to connect: in the Claude app,
   Customize → Connectors → Alis Build; in Claude Code, `/mcp` → `plugin:alisx:alis` →
   Authenticate. Stop there.
2. **Skills:** call `list_skills` with `page_size` 5 and `order` recent, and name the skills
   updated most recently, to show the Skill store answers.
3. **Conversations:** how many are open, and name the ones whose turn is the person's (subject
   and id). Say "none waiting on you" when there are none.
