---
name: discover
description: >-
  Find and load the right Alis Build skill from the AlisX Skill store, through the
  Alis MCP server. Use when the task is platform-shaped: creating or changing a
  product, service, code block or build environment; editing .proto contracts or
  running Define; building or deploying; Spanner schemas or protobundles; Pub/Sub
  event handlers; Terraform under a service's infra/; generated packages failing
  to resolve; playground tests; migrating legacy proto imports; ADK agents;
  sharing an HTML page, report or file as a link. Also on "alis, …", "hey alis",
  "ask alis to", "find a skill for …", "is there a skill for …". Not for generic
  coding (Makefiles, ordinary bugs, tests, git, reading logs) even inside an
  alis.build workspace, and not when a loaded Alis skill already covers the task.
---

# Discover — find and load the right Alis Build skill

Route quietly: find the best skill, load it, hand over. No preamble about running
discovery, and no narration when nothing fits.

## Flow

1. **Name the outcome.** Infer what the person wants done, in a sentence, from the
   request and the workspace (the package id and folder the session started in).

2. **Search once**: `search_skills` with that sentence as `query` and `limit` 5. The
   search goes by meaning; the results are the closest skills, not necessarily a fit.

3. **Judge the fit.** A skill fits when its description names this kind of work, not
   merely the same nouns. Unsure between two? `preview_skill` shows a skill's headings
   and files cheaply. When none fits, there is no skill: say nothing about discovery
   and do the work.

4. **Load and follow**: `load_skill` with the skill's id. Mention it in one clause
   ("Following the `<id>` skill.") and follow its instructions; it owns execution.
   Read files it names with `read_skill_file`. A long skill comes in parts: call
   `load_skill` again with the `offset` it gives.

5. **When a skill's step needs something this session cannot do** (for example an
   `alis` CLI command on a machine without the CLI), say which step and the exact
   command, and carry on with the steps that can be done here.

## Rules

- Discovery runs at most once per task: after a miss, do not search again on
  follow-up prompts about the same piece of work.
- If the person asked for a skill and nothing fits, say so and offer `request_skill`
  (a name, what it should help with, the work they were doing).
- When a skill was wrong, out of date or unclear, tell its owner with
  `send_skill_feedback`, naming the step.
- If the Alis tools are missing or ask for sign-in, say how to connect (Claude Code:
  `/mcp` → `plugin:alisx:alis` → Authenticate; the Claude app: Customize →
  Connectors → Alis Build) and continue helping without a skill.
