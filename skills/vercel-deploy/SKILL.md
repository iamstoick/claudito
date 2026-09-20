---
name: vercel-deploy
description: Deploy a project to Vercel end to end — detect Vercel targets, verify CLI auth and project link, validate the build locally with `vercel build` before pushing, set env vars, deploy, verify the live URL, read runtime logs, and roll back. Use whenever a task involves deploying, redeploying, debugging a failed deploy, or configuring a project on Vercel (vercel.json, .vercel/, *.vercel.app URLs, FUNCTION_INVOCATION_FAILED, serverless functions under api/).
---

# Vercel deploy

Goal: a deploy that either succeeds on the first push or fails **locally** with a
readable error. Never learn about a broken build from the Vercel dashboard.

## 0. Detect the target

Any of these means Vercel is in scope:
- `vercel.json` or `.vercel/project.json` in the repo
- `api/` directory holding serverless handlers
- a `*.vercel.app` URL in README/DEPLOY docs
- user says "Vercel", "preview deployment", "promote"

If the repo has its own `DEPLOY.md` / `docs/deploy*`, read it first and treat it
as authoritative over this skill.

## 1. Preflight (all read-only, run in one batch)

```bash
npx vercel --version                     # CLI present (npx pulls it if not installed)
npx vercel whoami                        # auth. Not logged in -> user runs: ! npx vercel login
cat .vercel/project.json 2>/dev/null     # linked? projectId/orgId
cat vercel.json 2>/dev/null
git status --porcelain; git branch --show-current
```

- **Not linked** -> `npx vercel link --yes` (picks existing project by dir name, or
  creates). Confirm with the user before *creating* a new project.
- **Not authenticated** -> stop. Auth is interactive; ask the user to run
  `! npx vercel login`. Do not try to script it. `VERCEL_TOKEN` env var is the
  CI alternative.
- **Dirty tree** -> say so. `vercel --prod` deploys the working tree, not HEAD;
  git-push deploys deploy HEAD. Know which one you are doing.

## 2. Validate the build locally — mandatory before any deploy

```bash
npx vercel pull --yes --environment=production    # fetch project settings + env into .vercel/
npx vercel build --yes --prod                     # full Vercel build, locally
ls .vercel/output/functions/                      # inspect what became a function
ls .vercel/output/static | head
```

This reproduces Vercel's build byte for byte in ~30s and catches every
structural error below without a round trip. **Check the functions listing**:
it must contain only the handlers you intend. Extra entries mean Vercel is
compiling source files as endpoints (see gotcha 1).

If `vercel build` fails, fix it here. Do not "try deploying to see".

## 3. Structural gotchas (each cost real hours; check them proactively)

1. **Everything under `api/` becomes a function, recursively.** Every `.ts`/`.js`
   file, including `api/src/routes/*.ts`, `api/db/migrate.ts`, test files. Symptom:
   dozens of nonsense functions and an opaque build error like
   `Unhandled type: "Identifier"` with no useful log line.
   Fix: `api/` holds **only** thin handler entry points. App code lives elsewhere
   (`server/`, `src/`, `lib/`) and is imported by relative path.

2. **ESM/CJS mismatch inside the function.** If the handler imports app code from a
   package with `"type": "module"`, `api/` needs its own `package.json` with
   `"type": "module"` too. Otherwise Vercel emits `require()` and the function
   crashes at load: `ERR_REQUIRE_ESM ... not supported`. Every `/api` route returns
   `FUNCTION_INVOCATION_FAILED` while static pages serve fine — the asymmetry is
   the tell.

3. **No `listen()` at module scope.** Export the app/handler; a `server.listen`
   in an imported module hangs the function import. Split `app.ts` (export) from
   `index.ts` (listen, for local/Docker).

4. **SPA + API rewrites.** For a static frontend and an `api/` function:
   ```json
   "rewrites": [
     { "source": "/api/(.*)", "destination": "/api/index" },
     { "source": "/(.*)",     "destination": "/index.html" }
   ]
   ```
   Order matters; the catch-all goes last. Keep API calls relative (`/api/...`)
   so auth cookies stay first-party.

5. **Multi-package repos without workspaces.** Set explicit `installCommand`,
   `buildCommand`, `outputDirectory` in `vercel.json` (e.g.
   `npm --prefix web ci && npm --prefix server ci`). Do not rely on framework
   auto-detect when the framework is not at repo root. Alternatively set
   **Root Directory** in project settings — but not both.

6. **Never put migrations in `buildCommand`.** Build runs on every preview with
   whatever env that branch has; you will migrate prod from a PR. Migrations run
   from a machine/CI against the **direct/unpooled** DB URL. Runtime uses the
   **pooled** URL. Session-level advisory locks do not work through a
   transaction-mode pooler.

7. **Schema drift.** The deploy is not atomic with the database. Before
   deploying code that depends on a migration, verify the migration is applied
   to the *target* DB (a `migrate:status`-style check that exits non-zero on
   pending). Yesterday's failure mode: migration applied locally, not to prod,
   code shipped, every request 500'd with `column ... does not exist`.

8. **`.gitignore`.** `vercel link` appends `.vercel` and sometimes `.env*`. Check
   the diff; `.env.example` must stay tracked.

9. **Node version.** `.vercel/project.json` `nodeVersion` / project settings must
   match `engines.node`. Mismatch shows up as syntax errors on modern syntax.

## 4. Environment variables

```bash
npx vercel env ls
npx vercel env add NAME production      # interactive value prompt; or:
printf '%s' "$VALUE" | npx vercel env add NAME production
```

- Vercel env vars do **not** interpolate (`$OTHER_VAR` is literal).
- Marketplace integrations (Neon etc.) inject their own names; read `env ls`
  rather than assuming `DATABASE_URL` exists. Add the exact name the app reads.
- Postgres: append `?sslmode=verify-full`. Never "fix" cert errors with
  `rejectUnauthorized: false`.
- **Env changes need a redeploy.** Existing deployments keep the values they
  were built with.
- Guard against shipping dev defaults (e.g. a `JWT_SECRET` equal to the
  `.env.example` value). If the app has such a guard, it fails at import time
  with a clear message — read it, don't bypass it.
- Set `Production` and `Preview` separately if previews should work.

## 5. Deploy

Prefer the path the project already uses:

```bash
# Git-connected project: push and let Vercel build
git push origin main
npx vercel ls                             # find the new deployment
npx vercel inspect <deployment-url> --wait

# Or direct from CLI (deploys working tree)
npx vercel --prod --yes                   # production
npx vercel --yes                          # preview
```

Prefer `npx vercel deploy --prebuilt --prod` after a successful `vercel build`:
it uploads the exact output you already inspected, so what you verified is
what ships.

## 6. Verify (each step isolates one layer)

```bash
URL=https://<app>.vercel.app
curl -s -o /dev/null -w '%{http_code}\n' $URL/                 # 200 static
curl -s -o /dev/null -w '%{http_code}\n' $URL/some/deep/route  # 200 SPA fallback
curl -s $URL/api/health                                        # function + DB
curl -s -o /dev/null -w '%{http_code}\n' $URL/api/<protected>  # 401 not 500
```

A protected route returning **401** proves the function booted and routing is
right. **500 / `FUNCTION_INVOCATION_FAILED`** means it crashed — go to logs.

## 7. Diagnose a failing deploy

```bash
npx vercel logs $URL                      # runtime logs (function crashes live here)
npx vercel inspect <deployment-url> --logs   # build logs
```

| Symptom | Cause | Fix |
|---|---|---|
| Build: `Unhandled type: "Identifier"` / many unexpected functions | source files under `api/` | move app code out of `api/` |
| Runtime: `ERR_REQUIRE_ESM` | `api/package.json` lacks `"type": "module"` | add it |
| Every `/api/*` = `FUNCTION_INVOCATION_FAILED`, static fine | function crashed at import | `vercel logs`; usually 2 above, or a throwing env guard |
| `/api/*` returns HTML | rewrite order wrong or handler path mismatch | catch-all last; check `.vercel/output/functions` name |
| `column ... does not exist` | migration not applied to target DB | run migration against unpooled URL, redeploy |
| Health says db:false (503) | function OK, DB unreachable | check `DATABASE_URL`, sslmode, pooled endpoint |
| Login OK, session never persists | cookie `Secure`/`SameSite` or cross-origin API | relative `/api` paths; `COOKIE_SECURE=true` |
| Works locally, env missing on Vercel | env set for wrong environment or not redeployed | `vercel env ls`; redeploy |
| Build uses wrong Node | project nodeVersion mismatch | set in project settings, match `engines` |

## 8. Rollback

```bash
npx vercel ls                                   # find last good deployment
npx vercel rollback <deployment-url-or-id>      # instant, re-points prod alias
# or
npx vercel promote <deployment-url-or-id>
```

Rollback does **not** revert the database. If a migration shipped, decide
explicitly whether it is backward-compatible with the old code before rolling back.

## 9. Report back

Always end with: deployment URL, what was verified (with status codes), env vars
touched (names only, never values), and anything left manual (migrations run,
DNS, integrations). If `vercel build` was skipped for any reason, say so.
