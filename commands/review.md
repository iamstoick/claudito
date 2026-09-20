---
description: Architecture-aware code review with Pharaoh
---

# Review with Pharaoh

The definitive code review. Architecture-aware, branch-aware, multi-agent, adversarial. Five phases that combine Pharaoh's knowledge graph with parallel specialized reviewers and an independent cross-model second opinion.

Final verdict: **SHIP** / **SHIP WITH CHANGES** / **BLOCK**

## When to Use

Before merging any branch. Before opening any PR. When reviewing changes that touch shared modules, export new functions, modify core data flows, or claim to implement a spec.

---

## Phase 0 — Git Context

**Goal:** Know exactly what changed and where you are. This phase is mandatory and runs before anything else.

1. Detect the current environment:
   ```bash
   git rev-parse --show-toplevel          # repo root (may be a worktree)
   git worktree list                      # detect if running in a worktree
   git branch --show-current              # current branch name
   git log --oneline -1                   # latest commit
   ```

2. Determine the base branch (what this branch diverged from):
   ```bash
   git merge-base HEAD main               # or master, or whatever the default is
   ```

3. Collect the full changeset from the base:
   ```bash
   git diff --name-only $(git merge-base HEAD main)...HEAD   # all changed files
   git diff --stat $(git merge-base HEAD main)...HEAD         # summary stats
   git log --oneline $(git merge-base HEAD main)..HEAD        # all commits on this branch
   ```

4. Also check for uncommitted work:
   ```bash
   git diff --name-only                   # unstaged changes
   git diff --cached --name-only          # staged but uncommitted
   ```

5. Extract the **touched modules** from the changed file paths. Group files by their top-level directory or module boundary. These module names feed Phase 1.

**Output of Phase 0:** Branch name, base branch, commit count, list of changed files, list of touched modules, and whether there's uncommitted work.

---

## Phase 1 — Pharaoh Recon

**Goal:** Get the full architectural picture in one call. Do NOT skip this phase — it is what makes this review architecture-aware instead of just a code diff review.

Call `pharaoh_recon` with:
- **repo:** The repository name
- **include_map:** `true`
- **modules:** The touched modules from Phase 0 (up to 5)
- **blast_radius:** The most critical changed files/functions as blast radius targets (up to 3). Pick the files with the most downstream risk — entry points, shared utilities, exported APIs.
- **dependencies:** Pairs of touched modules to trace coupling between (up to 3)

Then call these additional tools for data recon doesn't cover:
- `get_regression_risk` — overall change risk score for the repo
- `get_consolidation_opportunities` — duplicate logic the PR may introduce
- `check_reachability` — are new exports wired to entry points?
- `get_vision_docs` — read the repo's architectural contract. For every touched module, pull its relevant assertions. Any change touching code governed by a MUST-bullet must be checked against that assertion — if the change would violate the MUST, the verdict tips toward BLOCK unless VISION.md is updated in the same PR with user approval.
- `get_vision_gaps` — do changes align with or drift from specs? New complex functions without a matching assertion are flagged; retired specs with implementing code are flagged.

**Output of Phase 1:** Architecture map, module profiles for every touched module, blast radius for high-risk changes, dependency paths between coupled modules, regression risk level, duplication findings, reachability status, and spec alignment.

---

## Phase 2 — Parallel Specialized Review

**Goal:** Deep-dive the actual code changes from multiple expert angles simultaneously. Launch these as **parallel subagents** — they are independent and should run concurrently.

### Determine which reviewers to dispatch

| Agent | When to dispatch | Focus |
|-------|-----------------|-------|
| **Code Reviewer** | Always | Bugs, logic errors, CLAUDE.md compliance, code quality. Confidence-filtered (only issues >= 80/100). |
| **Security Reviewer** | When changes touch auth, encryption, tokens, tenant isolation, data access, billing, webhooks, Cypher queries, or any security-sensitive surface. Also dispatch when Phase 1 regression risk is HIGH. | OWASP Top 10, injection vectors, access control bypasses, tenant isolation violations, cryptographic misuse, secret exposure, plus project-specific security rules. See checklist below. |
| **Silent Failure Hunter** | When changes touch error handling, catch blocks, fallback logic, API calls, or any code that could suppress errors | Silent failures, broad catches, swallowed errors, missing user feedback, unjustified fallbacks. |
| **Test Analyzer** | When test files are changed, or when new functionality lacks corresponding tests | Behavioral coverage gaps, brittle tests, missing edge cases, tests that prove nothing. |
| **Type Design Analyzer** | When new types/interfaces are introduced or existing types are modified | Encapsulation, invariant expression, invariant enforcement. Rates each type 1-10 on four axes. |

### Security Reviewer — Checklist

The Security Reviewer agent runs a systematic audit against two layers: universal web security (OWASP) and project-specific invariants.

**Layer 1 — OWASP Top 10 + Common Vulnerabilities:**
- **Injection:** SQL/Cypher injection, command injection, XSS (reflected/stored/DOM), template injection
- **Broken auth:** Hardcoded credentials, weak token generation, missing expiry, session fixation
- **Broken access control:** Missing authorization checks, IDOR, privilege escalation, path traversal
- **Cryptographic failures:** Weak algorithms, plaintext secrets, missing encryption at rest/transit, key exposure
- **Security misconfiguration:** Permissive CORS, verbose error messages leaking internals, debug endpoints in production
- **Vulnerable dependencies:** Known CVEs in direct dependencies (check against changed package.json/lockfile)
- **SSRF:** Unvalidated URLs in fetch/request calls, redirect chains
- **Logging & monitoring:** Sensitive data in logs, missing audit trails for privileged operations

**Layer 2 — Project-Specific Security Rules (from CLAUDE.md):**
- Every Cypher query takes `repo` as first parameter — no unanchored MATCH clauses
- `validateRepoOwnership()` runs before every tool handler
- No default/fallback repo values — repo always from tenant's Postgres `tenant_repos`
- Tokens stored as SHA-256 hashes, never plaintext
- GitHub tokens encrypted at rest (AES-256-GCM with per-tenant HKDF-derived keys)
- Webhook signatures verified on every request (`PHARAOH_GITHUB_WEBHOOK_SECRET`)
- Org membership re-checked on every token refresh
- Tenant Neo4j users get `reader` role only — graph writes use admin connection
- Rate limiting enforced per tenant, not per user
- Neo4j admin credentials never leave server-side env vars

**Detection triggers (auto-dispatch when changed files match):**
- `src/auth/**`, `src/crypto/**` — authentication, encryption
- `src/mcp/server.ts`, `src/mcp/tenant-resolver.ts` — session management, tenant isolation
- `src/mcp/neo4j-queries.ts` — Cypher query construction
- `src/stripe/**`, `src/web/routes/billing.ts` — payment flows
- `src/github/webhooks.ts`, `src/web/routes/webhooks.ts` — webhook verification
- `src/db/**` — database access, schema changes
- `src/upload/**` — file upload validation
- Any file containing `validateRepoOwnership`, `runQuery`, `encryptProperty`, `verifyWebhookSignature`

**Output format:** Each finding must include:
1. Vulnerability class (e.g., "Cypher Injection", "Missing Ownership Check")
2. Severity: CRITICAL / HIGH / MEDIUM
3. Affected file:line
4. Attack scenario: how an attacker would exploit this
5. Remediation: specific code change required

### How to dispatch each agent

For each agent, launch a subagent (via the Agent tool) with:
1. The **git diff** of the relevant changed files (not the full session history)
2. The **Pharaoh context** from Phase 1 (architecture map, blast radius, module profiles) — this is what makes these agents architecture-aware
3. The **CLAUDE.md rules** relevant to the review (testing requirements, security non-negotiables, code style)
4. A clear instruction to focus ONLY on changed code, not pre-existing issues
5. For the **Security Reviewer** specifically: include the full Layer 2 checklist above and the list of security-sensitive file paths so it knows the project's threat model

Each agent returns a structured report with findings categorized by severity:
- **CRITICAL** (90-100): Must fix before merge
- **IMPORTANT** (80-89): Should fix before merge
- **SUGGESTION** (70-79): Consider for a follow-up

### What NOT to dispatch

- **Comment Analyzer** and **Code Simplifier** are polish agents. Do not include them in the review — they distract from correctness. Run them separately if wanted.
- Do not dispatch agents for trivial changes (typo fixes, dependency bumps, config changes). If Phase 0 shows < 20 lines changed across non-test files, skip Phase 2 entirely and go straight to Phase 4.

---

## Phase 3 — Adversarial Review

**Goal:** Independent second opinion on security-sensitive changes. A different agent evaluates the code fresh, without knowledge of your reasoning.

### When to trigger

Trigger Phase 3 when ANY of these are true:
- Changes touch **auth, encryption, access control, token handling, or session management**
- Changes touch **tenant isolation, query construction, or data access patterns**
- Changes touch **billing, subscription management, or payment flows**
- Changes modify **webhook verification or signature checking**
- Regression risk from Phase 1 is **HIGH**
- You are not confident about a specific change's correctness

If none of these triggers are met, **skip Phase 3** and proceed to Phase 4.

### How to run

1. **Prepare a review package** — do NOT send your session history:
   - The changed files (full diff or complete file contents)
   - What the code does and why it was changed (1-2 sentences)
   - Security constraints from CLAUDE.md (tenant isolation rules, encryption requirements, etc.)
   - Specific concerns you want the reviewer to focus on

2. **Dispatch to an independent subagent** with instructions to evaluate the code fresh and assign verdicts:

   | Verdict | Meaning |
   |---------|---------|
   | **AGREE** | Implementation is correct for the stated concern |
   | **DISAGREE** | Concrete issue identified with evidence and suggested fix |
   | **CONTEXT** | Cannot determine correctness — needs more information |

3. **Evaluate findings:**
   - AGREE items: no action
   - DISAGREE items: verify against actual code. If confirmed, it becomes a CRITICAL finding. If the reviewer lacked context, document why the current approach is correct.
   - CONTEXT items: provide the missing information and note it in the review output

---

## Phase 4 — Synthesis & Verdict

**Goal:** Merge all findings into a single, actionable review. No raw dumps — synthesize.

### Structure the output as:

```markdown
# Review: [branch-name] → [base-branch]

**[X] commits | [Y] files changed | [Z] modules touched**
**Worktree:** [path] (or "main repo")

---

## Architecture Impact
- Modules affected: [list with blast radius numbers]
- Dependency changes: [new coupling, removed coupling]
- Highest blast radius: [module/function] → [N downstream callers across M modules]

## Risk Assessment
- Regression risk: [LOW / MEDIUM / HIGH] — [one-line reason]
- Volatile modules touched: [list, if any]
- Wiring status: [all new exports reachable? / N unreachable exports found]

## Code Quality ([N] findings)

### Critical ([count])
- [finding with file:line, source agent, and fix]

### Important ([count])
- [finding with file:line, source agent, and fix]

### Suggestions ([count])
- [finding with file:line]

## Security ([N] findings, or "No security-sensitive changes")
- [Security reviewer findings with vulnerability class, severity, file:line, attack scenario, and remediation]
- [Or: "Security reviewer not dispatched — no security-sensitive files in changeset"]

## Test Coverage
- [Test analyzer summary — gaps, quality issues, positive observations]

## Spec Alignment
- [Vision gaps introduced or resolved]

## Adversarial Review
- [Phase 3 results, or "Skipped — no security-sensitive changes detected"]

---

## Verdict: [SHIP / SHIP WITH CHANGES / BLOCK]

[If not SHIP: numbered list of specific required changes before merge]
```

### Auto-block triggers (any of these = BLOCK)

- Any CRITICAL security finding (injection, broken access control, tenant isolation violation, secret exposure)
- Unreachable exports (new public code with zero callers)
- New circular dependencies between modules
- HIGH regression risk without corresponding test coverage
- **A MUST-bullet in `docs/VISION.md` is violated by this change** (without VISION.md being updated in the same PR with user approval)
- Vision spec drift: new complex function has no matching assertion AND the domain it lives in has existing assertions (implies invariants are expected here)
- Any CRITICAL finding from Phase 2 or Phase 3 that is confirmed and unfixed
- DISAGREE verdict from adversarial review on security-sensitive code, confirmed after verification
- Unanchored Cypher query (MATCH without traversing through `Repo {name: $repo}`)
- Missing `validateRepoOwnership()` on a new tool handler

### SHIP WITH CHANGES triggers

- IMPORTANT findings that are confirmed but non-blocking
- Test coverage gaps for new functionality
- Duplication that should be consolidated in a follow-up
- Spec drift that is intentional but should be documented

### SHIP triggers

- No CRITICAL or confirmed IMPORTANT findings
- All new exports are reachable
- Regression risk is LOW or MEDIUM with adequate test coverage
- Spec alignment is clean or intentionally divergent with documentation

---

## Quick Mode

For small changes (< 50 lines, single module, no security surface):
- Run Phase 0 + Phase 1 + Phase 4 only
- Skip Phase 2 (parallel agents) and Phase 3 (adversarial)
- Still architecture-aware, just faster

Explicitly opt in with: `/review quick`
---

Here is the task to review:

$ARGUMENTS
