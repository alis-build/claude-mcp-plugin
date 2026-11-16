---
description: List your conversations with Alis Build specialists, and whose turn each is. Add a search to find an older one.
---

Show the person's conversations with Alis Build specialists. Go by what they said with this
request, if anything (in Claude Code, the text after the command: $ARGUMENTS).

- With no words: `list_conversations` (open ones). Show a short table: subject, id, state, whose
  turn, last activity. Put the ones waiting on the person first.
- With words that describe a conversation: `search_conversations` with them as `query` (resolved
  ones included), and show the matches the same way.
- With an id (`tickets/<id>`): `get_conversation` and summarise where it stands, what was last
  said and by whom, and what the person could do next.

Read only; do not send, resolve or reopen anything unless the person then asks.
