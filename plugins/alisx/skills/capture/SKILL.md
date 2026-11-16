---
name: capture
description: >-
  Turn work just completed in this session into a reusable Alis Build skill in the
  AlisX Skill store, for the person's team — like recording a macro after doing the
  steps by hand. Use when the person says "make this a skill", "skillify this",
  "capture this as a skill", "save this as a skill", "record this as a skill", or
  "my team should have a skill for this". Also offer it (at most once per session,
  one line, dropped at once if declined) after multi-step Alis Build work that
  needed non-obvious steps AND that no existing skill covered. Never offer when an
  existing skill was loaded and followed for the task.
---

# Capture — save just-completed work as a team skill

Turn what was just done into a reusable skill: generalise the steps, not the session.
Everything goes through the Alis MCP server; a skill is published from its files with
`create_skill`, so nothing needs to be installed.

## Flow

1. **Dedupe first.** `search_skills` with what the work accomplished. On a close
   match, do not create a near-duplicate. Offer instead to:
   - follow the existing skill (`load_skill`);
   - improve it, when `list_skills` says the person may edit it (`update_skill`, with
     only the files that change);
   - tell its owner what was missing (`send_skill_feedback`).

2. **Confirm scope once.** Propose an id (lower-case words joined by hyphens; it
   cannot be changed later), a display name and a one-line description. Ask ONE
   question covering the id and what the skill should and should not cover. Do not
   iterate on naming.

3. **Write the files** (in the conversation, not yet published):
   - `SKILL.md`, starting with front matter that has `name` (the id) and
     `description`, then generalised, reusable steps with decision points and how to
     verify each — not a session log.
   - The description's first clause says what the skill does, then "Use when …"
     with the phrases a person would use. It is both what triggers the skill and
     what search matches, so write it for both.
   - Parameterise specifics: `<org>`, `<product>`, `<service>`, `<env>`.
   - Scrub: home and absolute paths, emails, build environment and project ids,
     tokens and keys, internal URLs. Never publish a secret: skills are read by
     everyone they are shared with.
   - Optionally `references/<topic>.md` for a scrubbed worked example.
   - **Code is not a reference.** If the practice needs a buildable foundation (a
     template tree, a Dockerfile, Terraform, a server), say that it belongs in a code
     block published from the source service (`alis blocks create`, see
     `alis docs codeblocks` where the CLI is installed), with this skill pointing to
     it, rather than files for agents to copy by hand.

4. **Review with the person.** Show the front matter and the step headings (not the
   whole file), plus a sample prompt the skill answers. Iterate on their comments.

5. **Publish only on explicit approval**: `create_skill` with `id`, `name`,
   `description`, `files` (each path inside the skill to its whole text, including
   `SKILL.md`) and `sample_prompt`. It publishes to the Skill store owned by the
   person.

6. **After publishing, say once** how the team gets it: they find it by describing
   the problem (search surfaces it), and the person can share it from the Skill
   store. Later changes go through `update_skill`; `list_skill_revisions` and
   `restore_skill_version` undo one.
