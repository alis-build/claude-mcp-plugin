---
description: Raise this session with the AlisX build team as a conversation, after you review exactly what will be sent. Add a note to say why.
---

The person wants the AlisX build team to see this session. Their note is what they said with
this request, if anything (in Claude Code, the text after the command: $ARGUMENTS).

1. **Find the thread.** `list_conversations`: if an open conversation is about this same work,
   offer to add to it with `send_message` instead of starting another.
2. **Write the message** a specialist can act on without the transcript (the transcript itself
   cannot be attached):
   - the person's note, first and in their words;
   - what they were trying to do, and where (package id, version, deployment environment);
   - what was done, what happened, and the exact error text, word for word;
   - what was tried, and what is still open.
3. **Files:** attach up to 10 short text files only where they help (a failing build log, the
   relevant config), from what the person pasted or uploaded here, each scrubbed of secrets, tokens and customer data. Never send a key,
   token, password or private key: write `[REDACTED]` in its place.
4. **Review:** show the person the subject, the message and the file names, and ask whether to
   send. Send only on a clear yes: `start_conversation` (or `send_message` to the open one).
5. Reply with the conversation's id and that a specialist will answer there; `wait_for_reply`
   only if the person wants to wait now.
