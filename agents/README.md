# Local Claude Code Subagents

Five subagents matching the GitHub Actions agents, for use inside a local Claude Code session (running in your terminal/IDE, not CI). Unlike the CI versions, these only run while you're actively in a session prompting Claude -- they don't fire unattended on repo events.

## Setup

1. Create a `.claude/agents/` folder in your repo (check it into version control so your whole team gets the same subagents), or `~/.claude/agents/` if you want these available across every project on your machine.
2. Copy the five `.md` files from this folder in.
3. That's it -- no separate install step. Claude Code picks these up automatically on your next session.

## How they get used

You don't have to name them. Claude Code reads each subagent's `description` field and matches it against what you're asking for:

- "This test is failing, can you figure out why" → delegates to `debugger`
- "I finished the auth changes, write up the PR" → delegates to `pr-writer`
- "Add a rate limiter to the API" → delegates to `code-writer`
- "Is this safe to deploy to prod" → delegates to `deploy-reviewer`
- "Write a Confluence page about this change" → delegates to `confluence-drafter`

If you want to force a specific one regardless of phrasing, type `@` and pick it from the list, or run `claude --agent debugger` to pin an entire session to one subagent.

## Matching the guardrails from the doc

- `pr-writer` and `code-writer` can run `gh pr create`/`gh pr edit` but never `gh pr merge` -- merging stays yours.
- `deploy-reviewer` has no deploy, push-to-protected-branch, or migration commands in its tool list at all. It's structurally incapable of deploying, not just instructed not to.
- `confluence-drafter` always writes to a local file for your review first, rather than publishing straight to Confluence.

## Adjusting these for your repo

The `tools:` and `Bash(...)` restrictions in each file are a starting point -- tighten or loosen them to match your actual toolchain (e.g. add `Bash(npm run lint:*)` to `code-writer` if that's part of your workflow). The frontmatter also accepts a `model:` field if you want to pin a subagent to a specific model once you've confirmed its exact API identifier -- left unset here so each subagent uses your session's default.
