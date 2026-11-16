---
name: specialist
description: >-
  Get help from Alis Build's specialists (people) through conversations on the Alis
  MCP server: read a conversation the person refers to, carry an open one on, start
  a new one with the whole problem, wait for a reply, and resolve it when settled.
  Use when the person mentions a ticket or conversation (tickets/<id>), asks to ask
  or tell Alis Build support, a specialist or the build team something, wants to
  know whether anyone answered, or when work is blocked by a platform-side failure
  that cannot be fixed in the repo (for example a platform-injected invalid_grant).
---

# Specialist — conversations with Alis Build's people

A specialist is a person. Everything sent is read by people and stored with the
conversation, so send only what the person asked to send, in their words or words
they approved.

## Read before acting

- A conversation the person refers to: `get_conversation` with its id
  (`tickets/<id>`). Given only a subject, `search_conversations` (resolved ones
  included) and match it; ask which when several match, and ask for the id when none
  does.
- Read it whole before proposing changes: the latest messages, whose turn it is, and
  its files (`read_attachment` with the name `get_conversation` gave).

## Start or carry on

1. `list_conversations` first: an open conversation on the same subject is carried on
   with `send_message`, not duplicated. A resolved one is reopened with
   `reopen_conversation` first.
2. A new one: `start_conversation` with
   - `message`: the whole problem in one go — what the person wanted, what was tried,
     the exact package, version and deployment environment, and error text word for
     word;
   - `subject`: a short line;
   - `files`: text files that help (a build log, the failing config), at most 10.
     Scrub secrets first; a call carrying a secret-looking value is refused.
3. Before sending, show the person the message (and the file names) unless they
   dictated it; send on their go-ahead.

## Waiting for an answer

- `wait_for_reply` with the conversation and the cursor the last call returned waits
  about two minutes and answers `replied` (with what was said) or `waiting`.
- On `waiting`, tell the person the conversation is with the specialist and move on;
  do not call it in a loop. Come back with `get_conversation` or `wait_for_reply`
  when they ask.

## Closing

`resolve_conversation` only when the person says the matter is settled.
