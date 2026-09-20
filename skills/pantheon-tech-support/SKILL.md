---
name: pantheon-tech-support
description: >
  Use this skill for ANY technical support task related to the Pantheon hosting platform. Triggers include: drafting or improving ticket responses (initial, follow-up, escalation, resolution), triaging incoming issues by priority, writing incident retrospectives or post-mortems, creating runbooks, and crafting customer-facing communications for any audience (end users, agencies, enterprise accounts, internal stakeholders like CSM/AM/leadership). Always use this skill when the user mentions support tickets, Zendesk, incidents, site outages, customer escalations, Pantheon platform issues, or asks for help with any support communication — even if they don't use the word "skill". This covers WordPress, Drupal, and Next.js hosting scenarios on Pantheon.
---

# Pantheon Technical Support Skill

A comprehensive skill for Gerald's Technical Support org at Pantheon, covering APAC, EMEA, and North America teams.

---

## Tone & Voice

All output — regardless of audience — should follow these principles:

- **Technically precise**: Use correct Pantheon terminology (environments, multidevs, AGCDN, edge, Autopilot, Quicksilver, etc.)
- **Empathetic but professional**: Acknowledge customer impact without being defensive or over-apologetic
- **Action-oriented**: Always close with a clear next step or owner
- **Appropriately concise**: Match length to urgency — P1s are brief and direct; write-ups are thorough
- **Honest**: Don't obscure what happened; customers and stakeholders trust directness

Adjust formality by audience (see [Audience Guide](#audience-guide) below).

---

## 1. Ticket Triage

When given a ticket description or summary, classify it using this framework:

| Priority | Criteria | Response SLA Target |
|----------|----------|-------------------|
| **P1** | Site completely down, total loss of functionality, data integrity risk, security breach | Immediate — within 15 min |
| **P2** | Major feature broken, severe performance degradation, checkout/auth failures, partial site down | Within 1 hour |
| **P3** | Partial degradation, workaround available, non-critical feature broken | Within 4–8 hours |
| **P4** | General question, how-to, low-impact cosmetic issue, feature request | Within 1 business day |

**Triage output format:**

```
Priority: P[1–4]
Reason: [One sentence justifying classification]
Suggested Owner: [Support Engineer / Platform Ops / CRE / Engineering escalation]
Immediate Action: [First thing the team should do]
Customer-Visible Impact: [What the customer is experiencing]
```

**Triage signals to watch for:**
- Redis/MySQL errors → likely P2 or P1 depending on scope
- AGCDN/WAF misconfig → potentially P1 if blocking all traffic
- Autopilot failures → P3 unless causing deploy loop
- PHP/NGINX errors on Live → P1 if 5xx site-wide, P2 if partial
- Multidev/Dev/Test only → downgrade one level (rarely P1)

---

## 2. Ticket Drafting

### 2a. Initial Response

Use when: A new ticket arrives and needs a first reply.

**Template:**

```
Hi [Customer Name],

Thank you for reaching out to Pantheon Support.

I've reviewed your report regarding [brief issue description] on [site name / environment].

[1–2 sentences acknowledging the impact and showing you understand what they're experiencing.]

Here's what I can confirm so far:
- [Observation 1 from ticket or logs]
- [Observation 2, if available]

To help us investigate further, could you please provide:
- [Specific info needed — e.g., error messages, timestamps in UTC, affected URLs]
- [Any recent changes — deploys, config updates, plugin/module changes]

I'm actively looking into this and will follow up with [next step or ETA].

[Closing line based on priority — see below]
```

**Closing lines by priority:**
- P1: `"We've flagged this as a critical issue and are treating it with the highest urgency."`
- P2: `"We're prioritizing this and will keep you updated as we make progress."`
- P3/P4: `"Please don't hesitate to reach out if anything changes in the meantime."`

---

### 2b. Follow-up / Waiting on Customer

Use when: Investigation is underway or blocked pending customer input.

```
Hi [Customer Name],

Just following up on [ticket subject].

[Update on what's been investigated / what was found, if anything.]

We're currently waiting on the following to move forward:
- [Item 1]
- [Item 2]

Once we have this, we'll be able to [next diagnostic step or resolution path].

Please let us know if you have any questions in the meantime.
```

**Note:** If no response after 48–72h, use a "pending closure" variant:
```
We haven't heard back regarding [issue]. If we don't receive a response within [X] business days, we'll close this ticket. Feel free to reopen it at any time.
```

---

### 2c. Escalation to Engineering

Use when: Issue requires platform-level investigation beyond Tier 1/2 scope.

**Internal escalation note (not customer-facing):**

```
## Escalation Summary

Ticket: [ID / Link]
Priority: [P1/P2]
Escalating Engineer: [Name]
Escalation Time: [UTC timestamp]

### What We Know
- [Confirmed symptoms]
- [Steps already taken]
- [What was ruled out]

### What We Need From Engineering
- [Specific ask — e.g., platform log access, infra-level investigation, code review]

### Customer Context
- Account type: [Agency / Enterprise / Standard]
- Business impact: [What's at stake for them]
- CSM/AM awareness: [Yes / No / Notified at HH:MM UTC]
```

---

### 2d. Resolution / Closing

Use when: Issue is resolved and ticket is being closed.

```
Hi [Customer Name],

I'm happy to let you know that [issue description] has been resolved.

**What happened:** [Brief, plain-language explanation of root cause]

**What was done:** [Actions taken to resolve — be specific]

**What you can do:** [Any recommended follow-up action on their end, or "No action needed on your part"]

If you experience any recurrence or have further questions, please don't hesitate to reply and we'll reopen this investigation.

Thank you for your patience while we worked through this.
```

---

## 3. Incident Write-ups

Use this structure for all post-incident documentation. Adapt depth based on severity (P1 = full write-up; P2 = condensed).

```markdown
# Incident Report: [Short Title]

**Date:** [YYYY-MM-DD]
**Severity:** P[1/2]
**Duration:** [Start UTC] → [End UTC] ([X hours Y minutes])
**Status:** Resolved / Monitoring / Ongoing
**Author:** [Name]
**Reviewed by:** [Name(s)]

---

## Summary
[2–3 sentences. What happened, what was affected, and how it was resolved. Write for a non-technical executive audience.]

---

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | [First signal / alert / customer report] |
| HH:MM | [Investigation began] |
| HH:MM | [Key finding] |
| HH:MM | [Mitigation applied] |
| HH:MM | [Resolution confirmed] |

---

## Root Cause
[Precise technical explanation. Include the contributing system, configuration, or code change that caused the issue. Reference specific Pantheon components (AGCDN, Redis, MySQL, Nginx, etc.) where relevant.]

**Contributing Factors:**
- [Factor 1]
- [Factor 2]

---

## Customer Impact
- **Sites affected:** [Number / list or "undisclosed"]
- **Impact type:** [Downtime / Degraded performance / Feature unavailability]
- **Customer segments:** [Enterprise / Agency / Standard]
- **CSM/AM notified:** [Yes — at HH:MM UTC / No]

---

## What Went Well
- [Thing 1]
- [Thing 2]

---

## What Could Be Improved
- [Thing 1]
- [Thing 2]

---

## Action Items
| Action | Owner | Due Date |
|--------|-------|----------|
| [Preventive measure] | [Team/Person] | [Date] |
| [Monitoring improvement] | [Team/Person] | [Date] |
| [Documentation update] | [Team/Person] | [Date] |
```

---

## 4. Runbooks

Use when creating step-by-step operational guides for recurring support scenarios.

**Runbook template:**

```markdown
# Runbook: [Scenario Title]

**Category:** [Incident Response / Triage / Escalation / Maintenance]
**Last Updated:** [Date]
**Owner:** [Team]

## When to Use This Runbook
[1–2 sentences on what symptoms or triggers indicate this runbook applies.]

## Prerequisites
- [ ] Access to [Pantheon dashboard / Terminus / logs / etc.]
- [ ] [Any other access or tool needed]

## Steps

### 1. [Step Title]
[Clear instruction. Include commands where applicable.]
```bash
terminus [command] --site=[site] --env=[env]
```

### 2. [Step Title]
[Instruction]

### 3. Escalate If
- [Condition that means this is beyond runbook scope]
- [Condition 2]

## Resolution Criteria
[How to confirm the issue is resolved.]

## Related Runbooks
- [Link or name]
```

---

## 5. Audience Guide

Adjust tone and content depth based on who you're writing for:

| Audience | Tone | What to Include | What to Omit |
|----------|------|-----------------|--------------|
| **End users / site owners** | Warm, plain language | What happened, what to do next | Technical internals, infra details |
| **Agency partners** | Professional, technically fluent | Root cause, timeline, workarounds | Overly internal metrics |
| **Enterprise / large accounts** | Formal, executive-ready | Business impact, SLA context, remediation commitments | Low-level debug details |
| **Internal (CSM/AM/Leadership)** | Direct, no fluff | Full picture — what happened, customer sentiment, escalation status, action items | Marketing softening |

---

## 6. Pantheon-Specific Context

Reference these when drafting tickets or write-ups:

- **Environments:** Dev → Test → Live (plus Multidevs)
- **Key services:** AGCDN (CDN/WAF), Redis (object cache), MySQL (database), Solr (search), Varnish (page cache), New Relic (APM)
- **Common tools:** Terminus (CLI), Quicksilver (workflow hooks), Autopilot (visual regression + auto-updates), Dashboard, Integrated Composer
- **CMS platforms supported:** WordPress, Drupal, Next.js (frontend frameworks via Decoupled)
- **Support tiers:** Standard, Diamond, Platinum — enterprise accounts often have dedicated CSM/AM
- **Escalation path:** Support Engineer → Senior SE → Platform Ops Support Engineering → Engineering (product/infra)

---

## Usage Notes

- When drafting, always ask for: site name, environment, ticket ID, and customer tier if not provided
- For P1s, draft the customer-facing response first, then the internal escalation note
- Incident write-ups should be reviewed by at least one other engineer before sending to customers or leadership
- For enterprise accounts, loop in CSM/AM before sending resolution notes
