# Claude Code setup

Personal, global Claude Code configuration. Everything here applies to every
project on this machine unless a repo's own `.claude/` overrides it.

Design goal: a small set of specialised agents with the right model and effort
for each job, a handful of skills that encode hard-won operational knowledge,
and hooks that make the important rules controls rather than suggestions.

## Layout

```
~/.claude/
├── CLAUDE.md              imports RTK.md and ENGINEERING.md into every session
├── ENGINEERING.md         engineering standards + agent routing rules
├── RTK.md                 RTK (token-saving Bash proxy) usage notes   [gitignored]
├── settings.json          model, effort, hooks, plugins               [gitignored]
├── agents/                subagents (one .md each) + agents/README.md
├── skills/                skills (one SKILL.md per directory)
├── hooks/                 scripts invoked by settings.json hooks
└── commands/              slash commands (currently Pharaoh's, see Leftovers)
```

`settings.json` and `RTK.md` are excluded by `.gitignore` (`*.json`, `RTK.md`).
To make the repo a full backup, add `!settings.json` and `!RTK.md` to
`.gitignore`. Until then, the "Settings" section below is the record.

## Settings (`settings.json`)

| Key | Value | Why |
|---|---|---|
| `model` | `claude-fable-5-1[1m]` | Fable with 1M context for the main session |
| `effortLevel` | `high` | default for models not listed below |
| `modelSettings.claude-fable-5-1.effortLevel` | `low` | main session runs cheap; agents carry the heavy reasoning |
| `modelSettings.claude-opus-5.effortLevel` | `medium` | |
| `modelSettings.claude-sonnet-5.effortLevel` | `low` | |
| `enabledPlugins` | `frontend-design`, `caveman`, `pantheon-skills` | |
| `hooks.PreToolUse[Bash]` | `rtk hook claude` | rewrites Bash through RTK for token savings |
| `hooks.PreToolUse[Bash, if git commit*]` | `hooks/pre-commit-secrets.sh` | gitleaks scan of staged changes, denies on a hit |

Per-agent model and effort live in each agent's frontmatter, not here.

## Agents (`agents/`)

Agents are pinned to a model and effort in frontmatter (`model:` / `effort:`).
Fable/high is reserved for work where reasoning depth changes the outcome.

| Agent | Model / effort | Role | Writes code? |
|---|---|---|---|
| `architect` | fable / high | Turns a feature request into a spec at `docs/specs/<date>-<slug>.md`: acceptance criteria, files to change, data/API changes, edge cases, security and performance notes, test plan | No. Writes only the spec |
| `code-writer` | fable / low | Implements from a spec or clear criteria. Greps before writing to avoid duplicates, runs tests, runs `dedupe-check` after | Yes |
| `debugger` | fable / high | Reproduces the failure, iterates on real output, adds a regression test | Yes |
| `security-reviewer` | fable / high | Walks inputs to sinks; reports exploitable findings with severity, attack, and fix | No |
| `deploy-reviewer` | sonnet / medium | Deploy risk read: schema, env drift, flags, rollback plan | No |
| `deployer` | sonnet / medium | Executes and verifies deploys. Loads `vercel-deploy` for Vercel. Hands unknown failures to `debugger` | Config only |
| `pr-writer` | sonnet / low | PR description from the real diff. Never merges | No |
| `confluence-drafter` | sonnet / high | Confluence-ready docs to a local file first | No |

Details and guardrails per agent: `agents/README.md`.

### Workflow

```
feature request
   │
   ├─ non-trivial (>2 files, new module/table/endpoint/dependency, ambiguous)
   │      └─▶ architect ──▶ spec in docs/specs/ ──▶ you approve ──▶ code-writer
   │
   └─ well-scoped ──────────────────────────────────────────────▶ code-writer
                                                                        │
                       diff touches auth, input handling, DB queries,   │
                       file/process access, crypto, secrets, deps?      │
                              yes ──▶ security-reviewer ──▶ fixes ──┐   │
                              no ───────────────────────────────────┴───┤
                                                                        ▼
                                                                    pr-writer
                                                                        ▼
                                                  deploy-reviewer ──▶ deployer
```

Agents cannot call each other. The main session sequences them and passes
file paths (the spec, the diff) between steps. Routing rules are in
`ENGINEERING.md`, so the main session applies them without being told.

## Skills (`skills/`)

| Skill | What it encodes |
|---|---|
| `vercel-deploy` | Full Vercel procedure: preflight, mandatory local `vercel build` before any deploy, structural gotchas (everything under `api/` becomes a function; ESM/CJS mismatch; no `listen()` at module scope; rewrite order; migrations never in `buildCommand`; schema drift), env var rules, layered curl verification, symptom table for `FUNCTION_INVOCATION_FAILED` and friends, rollback. Distilled from the Tadhana deploy |
| `dedupe-check` | jscpd-based duplicate detection. Grep-before-writing, scan-after-change with a fix/mention/ignore table, before/after baseline diff, repo audit, tuning, and what jscpd will not catch |
| `pantheon-tech-support` | Pantheon support communications (pre-existing) |

Plugin skills (`pantheon-skills`, `caveman`, `frontend-design`) come from
`enabledPlugins` and are not stored here.

## Hooks (`hooks/`)

`pre-commit-secrets.sh`: PreToolUse on Bash, filtered to `git commit`. Runs
`gitleaks git --staged` in the command's cwd. On a finding it returns a
`permissionDecision: deny` with file, line, and rule ID so the commit never
happens. Fails open with a visible message if gitleaks is not installed.

Test it without committing:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"'$PWD'"}' \
  | ~/.claude/hooks/pre-commit-secrets.sh
```

Empty output means clean.

## Standards (`ENGINEERING.md`)

Loaded into every session via `CLAUDE.md`. Sections: correctness (read before
edit, no duplicate code, failure paths, tests before reporting, no `any`),
security (parameterised queries, never disable a control to make something
work, secrets never in code or output, authz per object, dependency
justification), performance (measure first, no N+1 or unbounded lists,
`EXPLAIN` on query changes, serverless pool sizing), agent routing, and
communication style.

## External tools required

| Tool | Install | Used by |
|---|---|---|
| `rtk` | already installed | Bash hook, every session |
| `gitleaks` | `brew install gitleaks` | `hooks/pre-commit-secrets.sh`, `security-reviewer` |
| `jscpd` | none; runs via `npx` | `dedupe-check` |
| `vercel` CLI | none; runs via `npx` | `vercel-deploy` |
| `jq` | already installed | hook script |

## Gotchas

- **RTK rewrites Bash.** It turns `npx jscpd` into an npm subcommand (fails
  with `Unknown command`) and mangles JSON from `curl`/`gh api`. Anything whose
  output must be parsed exactly, or any `npx <tool>` call, goes through
  `rtk proxy <cmd>`. Skills already do this.
- **New hooks need a reload.** Claude Code only watches settings files that
  existed at session start. After editing hooks, open `/hooks` once or restart.
- **Agent changes need a new session** to be picked up.
- **Effort override.** `modelSettings.claude-fable-5-1.effortLevel: low` wins
  over the global `effortLevel: high` for the main session. That is intended;
  do not "fix" it. Raise effort per agent in frontmatter instead.
- **Auto mode blocks self-modification.** In auto mode the classifier refuses
  edits to `agents/*.md`, `settings.json`, and MCP registration. Switch modes
  or run those commands yourself with `! <cmd>`.

## Leftovers

Pharaoh (hosted code-graph MCP) was trialled and replaced by jscpd because the
graph server is closed-source and cannot run locally. Remnants that can be
removed:

```bash
claude mcp remove --scope user pharaoh
rm -rf ~/.claude/plugins/data/pharaoh ~/.claude/commands/{plan,review,sessions,vision}.md
```

Then delete the `pharaoh@pharaoh-so` entry from
`plugins/installed_plugins.json`. Its core skill otherwise nags every session
to call `get_codebase_map`.

## Maintenance

- Commit this directory after changes. `git log` is the changelog.
- When a deploy or debugging session teaches something non-obvious, put it in
  the relevant skill's symptom table, not in memory. Skills load on demand;
  memory does not enforce anything.
- Keep agents single-purpose. If one starts needing two models, split it.
