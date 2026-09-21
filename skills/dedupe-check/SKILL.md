---
name: dedupe-check
description: Detect duplicate and copy-pasted code with jscpd, locally, no account. Use before writing a new function (is there already one like it?), after finishing a change (did I introduce a clone?), or when asked to find, audit, or reduce duplicated code, DRY violations, or copy-paste in a repo. Works on TS/JS/TSX, Python, PHP, Go, CSS, and 150+ formats.
---

# dedupe-check (jscpd)

jscpd is a token-based copy/paste detector. It finds blocks of code that are
structurally identical (identifiers can differ), not semantic overlap. Fast:
a 7k-line repo scans in under a second.

## Invocation

**Do not run `npx jscpd` bare in this environment.** The RTK hook rewrites it into
an npm subcommand and it fails with `Unknown command: "jscpd"`. Use one of:

```bash
rtk proxy npx --yes --package=jscpd jscpd <paths> [flags]
# or, if installed globally (npm i -g jscpd):
jscpd <paths> [flags]
```

## Mode 1: before writing a function

Purpose: find out whether the logic already exists. jscpd cannot search for
code you have not written yet, so this mode is two steps:

1. Grep for the intended name, its synonyms, and 2-3 distinctive tokens the
   body will contain (an error code, a header name, a field name).
2. Read the hits. Reuse or extend rather than write.

Then write the code and go to Mode 2.

## Mode 2: after a change (the enforced check)

Scan the packages you touched, scoped to source, with a sensible floor:

```bash
rtk proxy npx --yes --package=jscpd jscpd <src dirs you touched> \
  --min-tokens 50 --min-lines 5 \
  --ignore '**/*.test.*' --ignore '**/*.spec.*' --ignore '**/dist/**' \
  --ignore '**/node_modules/**' --ignore '**/*.d.ts' \
  --gitignore --reporters console
```

Read every `Clone found` block. For each one, decide:

| Clone involves | Action |
|---|---|
| Two places, at least one is code you just wrote | **Fix now.** Extract a shared function/component/mixin and call it from both. |
| Two places, both pre-existing, in files you touched | Fix if small and safe; otherwise mention in the summary. |
| Two places, neither touched by you | Leave it. Mention in the summary. Do not expand scope. |
| Test fixtures, generated code, migrations, lockfiles | Ignore. Add an `--ignore` glob if it recurs. |

A repo-wide baseline of 1-2% duplicated lines is normal. The goal is zero
**new** duplication from your change, not zero total.

### Comparing against baseline

To prove you added no clones, diff before and after:

```bash
git stash && rtk proxy npx --yes --package=jscpd jscpd <dirs> --min-tokens 50 --reporters json --output /tmp/jscpd-before --silent; git stash pop
rtk proxy npx --yes --package=jscpd jscpd <dirs> --min-tokens 50 --reporters json --output /tmp/jscpd-after --silent
python3 -c "import json;a=json.load(open('/tmp/jscpd-before/jscpd-report.json'))['statistics']['total'];b=json.load(open('/tmp/jscpd-after/jscpd-report.json'))['statistics']['total'];print('clones',a['clones'],'->',b['clones'],'| dup lines',a['duplicatedLines'],'->',b['duplicatedLines'])"
```

Clone count went up: you introduced duplication. Fix or justify.

## Mode 3: audit a repo

```bash
rtk proxy npx --yes --package=jscpd jscpd . --min-tokens 50 --min-lines 5 --gitignore \
  --ignore '**/node_modules/**' --ignore '**/dist/**' --ignore '**/*.test.*' \
  --reporters console,html --output ./.jscpd-report
open .jscpd-report/html/index.html
```

Group findings by fix, not by file: "five login/register/reset form fragments
-> one `AuthForm` shell" is one item, not five.

## Tuning

| Flag | Default | Use |
|---|---|---|
| `--min-tokens N` | 50 | Raise to 70-100 to cut noise in boilerplate-heavy code (React JSX, Express routes). Lower to 30 for tight utility code. |
| `--min-lines N` | 5 | Floor on block length. |
| `--threshold N` | none | Exit non-zero if duplicated % exceeds N. For CI. |
| `--format ts,tsx,python` | all | Restrict languages. |
| `--mode strict\|mild\|weak` | mild | `strict` counts whitespace/comments too. Stay on `mild`. |
| `--blame` | off | Adds git author per clone. Useful in audits, noisy otherwise. |
| `--reporters json` + `--output DIR` | console | Machine-readable `jscpd-report.json`. |
| `--gitignore` | off | Respect .gitignore. Always pass it. |

Persist repo settings in `.jscpd.json` at the repo root so every run agrees:

```json
{
  "minTokens": 50,
  "minLines": 5,
  "gitignore": true,
  "ignore": ["**/node_modules/**", "**/dist/**", "**/*.test.*", "**/*.spec.*", "**/*.d.ts", "**/migrations/**"],
  "reporters": ["console"]
}
```

## Limits (know what it will not catch)

- **Renamed-and-reordered logic.** Same algorithm, different statement order or
  restructured control flow is invisible. Grep and reading still matter.
- **Semantic duplicates.** Two functions that do the same thing with different
  code. Only a human or a call-graph tool catches these.
- **Cross-language.** A TS validator and its Python twin are not compared.
- **Tiny helpers.** A 3-line duplicate is under the floor by design. Lower
  `--min-tokens` if that matters for the file at hand.

## Report format

End with one line per clone acted on: `file:line <-> file:line -> what you did`.
Then a single line for anything left as-is and why. No totals table unless
the user asked for an audit.
