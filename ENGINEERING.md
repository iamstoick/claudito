# Engineering standards

Apply to every project unless the repo's own CLAUDE.md says otherwise. These
are defaults for code I write or change; they are not a license to refactor
code I was not asked to touch.

## Correctness first

- Read the code you are changing and its callers before editing. Never edit from a description alone.
- Match the repo's existing conventions (naming, error handling, test style, formatting) over personal preference.
- No duplicate code. Grep for an existing function before writing one. Extract shared logic when the same thing appears twice. Run the `dedupe-check` skill after a change.
- Handle failure paths: invalid input, empty results, timeouts, partial writes, concurrent callers. Say explicitly which cases are left unhandled and why.
- Smallest change that satisfies the request. No speculative abstractions, config knobs, or "future-proofing" for needs that do not exist yet.
- Tests for new logic, run before reporting. A change is not done until the existing suite passes. Report failures verbatim, never as "should work".
- Typed languages: no `any`, no unchecked casts, no `@ts-ignore` / `# type: ignore` without a one-line reason next to it.

## Security

- Treat every external input as hostile: HTTP params, headers, env, files, DB rows written by others, LLM output.
- Parameterized queries only. Never build SQL, shell, or HTML by string concatenation with user data.
- Never disable a security control to make something work (`rejectUnauthorized: false`, `verify=False`, `--no-verify`, `eval`, `dangerouslySetInnerHTML`, wildcard CORS). Find the actual cause.
- Secrets live in env or a secret manager, never in code, tests, fixtures, logs, or commit history. `.env.example` holds placeholders only. Never print secret values in a summary; name the variable.
- Guard against shipping dev defaults to production (a `JWT_SECRET` equal to the example value, `DEBUG=true`). If a guard exists, do not work around it.
- Authz on every endpoint and every object access, not just authn. Check that the caller may act on *this* resource.
- Dependencies: no new dependency without saying why existing ones cannot do it. Prefer well-maintained, small, already-present packages. Pin versions in lockfiles.
- Run `/security-review` or the `security-reviewer` agent before opening a PR that touches auth, input handling, crypto, file or process access, or dependencies.

## Performance

- Measure before optimizing. Name the metric (p95 latency, query count, bundle KB, memory) and the number, before and after.
- Watch the hot path: no N+1 queries, no unbounded `SELECT *` or list endpoints without pagination, no synchronous I/O in request handlers, no O(n²) over user-sized data.
- Query changes get an `EXPLAIN` or equivalent. New filters get an index or a reason why not.
- Frontend: no new heavy dependency without checking bundle impact; lazy-load what is not needed on first paint.
- Serverless / short-lived processes: no module-scope `listen()`, small connection pools, pooled DB endpoints at runtime.
- Do not trade clarity for micro-optimizations without a measurement that justifies it.

## Routing work to agents

- **Feature or non-trivial change** (more than two files, a new module, table, endpoint, dependency, or public interface, or an ambiguous request): send to `architect` first. It writes a spec to `docs/specs/`. Show the user the spec path and summary and wait for their OK before handing the spec path to `code-writer`.
- **Well-scoped change** (clear acceptance criteria, one or two files): straight to `code-writer`.
- **Failing test, error, unexpected behavior**: `debugger`.
- **Diff touches auth, sessions, input handling, DB queries, file/process access, crypto, secrets, or dependencies**: `security-reviewer` before `pr-writer`.
- **Deploy**: `deploy-reviewer` for the risk read; `deployer` to execute.
- Agents cannot call each other. The main session sequences them and passes file paths, not summaries, between steps.

## Communication

- Lead with the outcome. If something could not be verified, say so first.
- Name trade-offs in one sentence, pick, move on. Do not present a menu unless asked.
- Push back once if a request would harm the codebase; if reaffirmed, do it as asked and say so.
- Summaries list: what changed, what was verified (with the command and result), what was skipped and why.

## Tooling notes

- Bash commands run through the RTK hook, which rewrites and filters output. When a command's output must be parsed exactly (JSON from an API, `npx <tool>` invocations that RTK misroutes), prefix with `rtk proxy`.
