---
description: Draft a VISION.md for this repo by filling a graph-derived scaffold
---

# Vision Drafting

Author a VISION.md that captures this repo's invariants — what must always be
true about its behavior. The file becomes a machine-readable contract that
Pharaoh's linter, PR Guard, and MCP tools reason against on every change.

## Why this matters (explain this to the user before drafting)

A VISION.md is leverage, not paperwork. Once the repo has one:

- **PR Guard** checks every pull request against its assertions. Changes that
  contradict a MUST-bullet surface as a Check on the PR — the team sees drift
  from intent at the exact moment it happens, not months later.
- **`get_vision_gaps`** becomes useful. Pharaoh cross-references every spec
  against the function graph and surfaces both sides of the drift: specs
  without implementing code (dead intent) and complex functions with no spec
  (invisible invariants).
- **`get_vision_docs`** returns spec-to-code traceability. Each assertion
  shows the functions that implement it — a direct map from intent → code.
- **CI enforces it.** Every MUST bullet pairs with a TEST reference. The
  linter fails when an assertion has no enforcing test. No more wishlist
  specs that drift over time.

Without a VISION.md, the tools above return empty. The graph sees code; it
doesn't see intent. The file is the bridge.

## When to Use

- The repo has no `docs/VISION.md` yet and the user wants Pharaoh's full
  value — PR Guard, vision-gaps, spec traceability all depend on the file.
- `get_vision_docs` returned the "No VISION.md yet" onboarding response.
- The user said "draft a vision doc", "add a VISION.md", or "scaffold vision".
- A user is new to Pharaoh and asking what they should do next.

## The flow — collaborative, not solo

This is a short working session with the user. Do not solo-fill the scaffold
— the graph can tell you the shape of the code, but only the user knows what
must not break. Ask questions, propose, let them steer.

1. **Get the scaffold.** Call `get_vision_docs` with the repo name. When no
   vision doc exists, the tool returns a deterministic scaffold plus the
   agent directive. Use that as your starting structure. Never invent a
   scaffold from scratch; the archetypes encode Pharaoh's framework shape
   and drift is surfaced by the framework-linter.

2. **Interview the user.** Before filling anything, ask: *"What are the 3-5
   things about this repo that must not break, no matter what?"* Their
   answer drives the assertions. If they can't articulate it, probe with
   follow-ups — "what would a P0 incident look like here?", "what would
   wake you up on a weekend?". The goal is to extract real invariants, not
   to generate plausible-sounding ones from graph evidence.

3. **Ground each domain in real code.** For every `## Domain` the scaffold
   rendered, call `get_module_context` for the module(s) that back that
   domain. For example, an "Authentication and Authorization" domain →
   `get_module_context` on the auth module + any session/token modules.
   Read the exported functions, endpoints, env vars, and DB access.

4. **Replace TODOs with WHAT statements.**
   - Every `### TODO:` heading becomes a real assertion title. Describe the
     invariant in plain language — "Sessions expire after 30 minutes of
     inactivity", not "checkSession() returns null after timeout".
   - Every `- MUST: TODO —` bullet becomes a WHAT statement. Banned
     content: function names, file paths, class names, identifiers.
   - Add a `- TEST: path/to/test.ts` line for every assertion. If the test
     doesn't exist yet, write it before committing. A MUST without a TEST
     is not an invariant, it's a wish.

5. **Trim irrelevant domains.** If a rendered `## Domain` doesn't match
   anything real in this repo, delete that whole section. The scaffold is a
   starting point, not a contract to honor exhaustively.

6. **Write the file.** Save to `docs/VISION.md` in the repo. Remove the
   `<!-- scaffold-generated -->` marker and the `<!-- AGENT DIRECTIVE -->`
   block once every TODO is resolved.

7. **Wire it into CLAUDE.md.** This is non-negotiable — it's what turns the
   vision doc from a file on disk into a contract future sessions respect.
   If `CLAUDE.md` exists at the repo root, append (or edit) a section:

   ```markdown
   ## Vision docs

   `docs/VISION.md` is this repo's architectural contract. Before any
   non-trivial change, call `get_vision_docs` to read the relevant
   assertions. After any large refactor, run `get_vision_gaps` to surface
   drift between intent and implementation. When adding a new invariant,
   open `docs/VISION.md`, add a `### assertion` under the right `##` domain,
   and pair every `- MUST:` with a `- TEST:` referencing the enforcing test.

   Never introduce code that would violate a MUST-bullet without first
   updating `docs/VISION.md` (with the user's approval).
   ```

   If no `CLAUDE.md` exists, create a minimal one with the section above
   plus any project-specific instructions you already have context for.

8. **Verify.** Run `pharaoh vision lint --framework` (or instruct the user
   to). Zero errors. Zero TODO warnings. Zero unresolved placeholders.

## Hard rules

- **No HOW in MUST bullets.** Banned: function names, file paths, camelCase
  identifiers, backtick-wrapped code. The linter enforces this as a warning;
  treat it as a hard rule.
- **Every MUST needs a TEST.** The format-linter errors if a MUST bullet
  has no matching TEST reference to an existing file.
- **One MUST per line.** Don't pack multiple invariants into a single bullet.
- **Max 10 prose lines per assertion.** Keep each `###` section tight.
- **Mirror Pharaoh's canonical domains when they fit.** Rename only when the
  user's project truly has a different shape. The framework-linter warns on
  unrecognized domains so drift is visible.

## What to avoid

- **Do NOT** write VISION.md from scratch without calling `get_vision_docs`
  first — you'll miss domains the graph detected and duplicate ones it
  already included.
- **Do NOT** carry forward the AGENT DIRECTIVE or scaffold-generated marker
  into the committed file. Those are drafting aids, not document content.
- **Do NOT** write speculative assertions ("sessions will expire someday").
  Only assert what the code enforces today or what you'll commit a test for.
- **Do NOT** use `pharaoh vision init` — that only drops the format guide,
  not a graph-grounded scaffold. Always go through `get_vision_docs`.

## Completion checklist

- [ ] User was interviewed for their real invariants (not graph-guessed)
- [ ] Every rendered `## Domain` either has ≥1 real assertion or was deleted
- [ ] Every `### TODO:` heading replaced with a real title
- [ ] Every `- MUST: TODO —` replaced with a WHAT statement
- [ ] Every assertion has a `- TEST:` line pointing at an existing test file
- [ ] Scaffold marker + AGENT DIRECTIVE block removed
- [ ] `CLAUDE.md` updated (or created) with the Vision docs section
- [ ] `pharaoh vision lint --framework` exits clean

## After it ships — tell the user what they unlocked

Once `docs/VISION.md` is committed, call out the new capabilities concretely:

1. **Every future AI session reads it.** Because CLAUDE.md now references
   `docs/VISION.md`, any agent working in this repo (Claude Code, Cursor,
   anyone else connecting Pharaoh) will consult the file before touching
   architecture. Continuity across sessions, across people, across tools.
2. **`get_vision_docs`** now returns spec-to-code traceability per
   assertion. The user can see which functions implement each invariant.
3. **`get_vision_gaps`** surfaces drift. Unspecified complex functions
   get flagged; specs with no implementing code get flagged for review
   (either write the code or retire the spec).
4. **Their next PR is checked.** PR Guard now evaluates touched code
   against relevant assertions. First-time use often catches real drift.
5. **`/pharaoh:plan`** will surface relevant assertions during reconnaissance.
6. **`/pharaoh:review`** will flag PRs that touch code governed by a MUST.

The bigger payoff: architectural invariants are now enforced in CI the same
way unit tests enforce behavior. Intent and implementation stop drifting.

## Ongoing maintenance — it's a living file

VISION.md rots if it's not maintained. Part of your job in future sessions
(even ones that aren't about vision directly) is to keep it current:

- **When a MUST changes**, update VISION.md in the same PR as the code
  change. Don't let the file lag — stale assertions are worse than none.
- **When a new architectural decision lands**, add a new `###` assertion
  under the right `##` domain with a pairing TEST. One assertion per
  decision, not batches.
- **When an assertion stops being load-bearing**, delete it. Retirement is
  as important as addition.
- **When `get_vision_gaps` shows >5 unimplemented specs**, the doc has
  drifted into wishlist territory. Prune.
- **Quarterly**: run `pharaoh vision lint --framework` and address warnings.

Format reference: https://pharaoh.so/vision-format.md
---

Here is any additional context for the vision draft:

$ARGUMENTS
