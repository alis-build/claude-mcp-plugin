## The `alis` CLI is on this machine

Steps no MCP tool covers yet run through it; `alis docs` and `alis <cmd> --help` are
its source of truth. Define: `alis define <pkg> --json --install`. Build:
`alis build <pkg> --json --deploy -e <env> --async`. Deploy:
`alis deploy <pkg> --version <version> -e <env> --json --async`. Packages:
`alis packages install|upgrade|add <pkg> --json`. Deployment environments:
`alis environment list <org>.<product> --json` (no variable values).

- One standalone `alis` command per Bash call, with `alis --cwd /absolute/path …`
  instead of `cd … &&`; no pipes, `head`, `tail`, `2>&1` or redirects. Under `--json`
  stdout is one final JSON object and stderr is progress.
- Never poll with `sleep`: block with `alis operations wait <op> --json`. `done: true`
  with `status: succeeded` is finished; a deployment `state` of `RUNNING` means up and
  serving.
- A production deploy exits with code 3 until re-run with `--confirm-production`,
  which needs the person's explicit approval. On `APPROVAL_REQUIRED`, add `--approve`
  only when the person asked for that exact action on that target.
- Exit code 4 means signed out: the person runs `alis login`. A git auth failure
  against an Alis remote: `alis authorise <org>.<product> --json` once.
- Diagnose before re-running: `alis operations describe <op>`, `alis doctor --json`,
  `alis logs build|deploy <op> --json`.
