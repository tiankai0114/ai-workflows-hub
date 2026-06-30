# AI Workflows Hub — Presentation Script (English)

> **Total duration:** 10–12 min presentation + 2 min Q&A
> **Audience:** Team Leaders, VPs
> **Slides:** 12 slides (use `→` / Space to advance)

---

## Slide 1 · Cover (30 sec)

Good [morning / afternoon], everyone.

I want to start with one sentence that captures everything I'm about to show you:

**You write a GitHub Issue, add a label, and Claude plans the work, writes the code, reviews the PR — your engineer just clicks Merge.**

This is not a proof of concept. It's running in production today, and any team here can be onboarded in under 20 minutes. That's what I'll walk you through today.

---

## Slide 2 · The Problem (1 min)

Let me start with why we built this.

The first issue is **duplicated AI effort**. Right now, every team that wants to adopt AI tooling has to build it from scratch — different approaches, inconsistent quality, no shared learning across the org. We're reinventing the wheel repeatedly.

The second is **no standard for AI-assisted development**. AI adoption is ad-hoc and fragmented. There's no common workflow, no shared design pattern, nothing that scales.

The third is **third-party integrations rebuilt repeatedly**. Every team re-implements Jira, Teams, CloudWatch connectors. That's complex infrastructure work that takes engineers away from building product.

And the fourth — probably the one that leadership cares most about — is **security and compliance**. Uncontrolled AI tool usage means code potentially leaving the company, API keys getting exposed, no unified governance.

This platform solves all four.

---

## Slide 3 · The Solution (1 min)

So what is AI Workflows Hub?

It's a **shared platform** of pre-built, battle-tested AI workflow templates. Any team references them with a single line — no infrastructure to manage, no AI logic to copy.

Three pillars:

- **Shared Templates** — don't rebuild from scratch, just reference
- **Standardized Patterns** — common design patterns like PGE that encode best practices
- **Plug-and-Play Integrations** — Jira, Teams, CloudWatch, GitHub — pre-built connectors that teams use as pure APIs

The core principle: **teams focus on what to build — the platform handles how AI does it.**

One more thing worth calling out: this isn't designed from scratch. It's been **evolved from the Quote team's production AI development process** — real projects, real PRs, real edge cases already handled.

---

## Slide 4 · Design Patterns (45 sec)

The platform is built around standardized AI workflow patterns — think of them as reusable building blocks.

The first and most important pattern that's live today is **PGE — Plan, Generate, Evaluate**.
This is the full AI-assisted development pipeline: Issue goes in, Claude plans milestones, writes the code, evaluates the PR, and your engineer merges. Handles the entire dev lifecycle.

Two more patterns are on the roadmap:

- **SAG** — Search, Analyze, Generate — for information retrieval and synthesis workflows
- **CAR** — Collect, Analyze, Report — for log monitoring and automated reporting

Each pattern is a module. Teams compose them based on what they need.

---

## Slide 5 · API Layer (1 min)

This is the slide I want to spend a moment on, because it shows **how clean the developer experience is**.

On the left — the team-facing APIs. Five workflow modules: plan, decompose, generate, evaluate, code-review. All live today. The team side is dead simple:

```yaml
uses: ai-workflows-hub/.github/workflows/pge-plan.yml@main
```

That's it. One line. Authentication, retry logic, Bedrock invocation, GitHub App token management, Jira integration — all of that lives on the right side, inside the platform. Teams never touch it.

The platform handles the complexity so your engineers don't have to learn it, maintain it, or debug it.

---

## Slide 6 · Flexible Adoption (45 sec)

You don't have to adopt the full pipeline on day one.

**Option A — Full pipeline**: Issue all the way to reviewed, merged PR. Best for teams starting new features.

**Option B — Modular**: Pick only what solves your immediate pain point. Just the Code Review module to speed up PR review. Just the Log Monitor to reduce on-call burden. Start small, expand over time.

The numbers that matter:

- **≈ 20 minutes** to onboard any repo
- **Zero** ongoing maintenance — no infrastructure to run
- **Zero** AI logic in your repo — all of it lives in the hub

---

## Slide 7 · Onboarding (45 sec)

So what does 20 minutes look like in practice?

**Step 1 (2 min):** Add one YAML file to your repo — it just points to the hub, no AI logic to copy.

**Step 2 (5 min):** Set the AWS OIDC Role ARN in GitHub Secrets for secure authentication. No long-lived keys, no secrets stored anywhere.

**Step 3 (8 min):** Add the `ready` label to a test Issue and confirm the workflow fires correctly.

**Steps 4 & 5 (5 min):** Set up your GitHub App bot account and add the issue label templates.

Five steps, under 20 minutes, and your repo has a full AI-assisted development pipeline. We have a step-by-step guide and scripts to automate most of it.

---

## Slide 8 · Trigger Flow (1.5 min)

Let me show you exactly how the two human touchpoints work.

*(Advance through the animation)*

**Touchpoint 1 — Direction approval:**
A developer creates an Issue using our standard template. They add the `ready` label. Claude Planner automatically scans the codebase, identifies open questions, runs up to three rounds of Q&A to clarify scope, then posts a structured milestone plan as a comment.

The engineer reads it. decide whether to continue next process? Add the `implement` label. That's the authorization to proceed.

**Touchpoint 2 — Final review:**
Claude Generator writes the code, commits as a bot, opens the PR. Claude Evaluator runs build, lint, tests, does a multi-dimension code review. If it doesn't pass, it automatically triggers rework — up to five rounds. Once it passes, the PR is labeled `approved` and a human does the final review and merges.

That's the entire pipeline. **Two label clicks. Everything else is AI-driven.**

---

## Slide 9 · Current Status (30 sec)

Here's where things stand today.

The platform is **fully operational**: GitHub-based workflows running, AWS Bedrock with OIDC authentication, no stored API keys, ~20 min onboarding.

The PGE pattern is live with the full feature set: multi-milestone planning, scope management with explicit exclusion tracking, CI gate before code review, Figma design fidelity checks, and automatic rework loops.

Jira and Teams integrations are in progress. Bitbucket support is planned for teams not on GitHub.

---

## Slide 10 · Live Demo (2–3 min)

Let me stop talking about it and just show you a real run.

*(Switch to browser — open the pre-prepared Issue)*

This is a real Issue in a repo that's already connected to the hub. Everything you're about to see is the actual output — nothing was manually written.

**Step 1 — The Issue.**
Here's the Issue, written with our standard template. Just a plain description of what we wanted to build. Nothing special. Then we added the `ready` label — that's all it took to kick off the entire process.

*(Scroll down to the first bot comment)*

**Step 2 — The Plan.**
Claude Planner scanned the codebase and posted this milestone plan right here in the thread. You can see it broke the work down, flagged open questions, and defined exactly what's in scope — and what's explicitly excluded. This is what the engineer reviewed and approved before anything was written.

*(Add `implement` label was applied — show the PR linked)*

**Step 3 — The Code.**
Once the `implement` label went on, the Generator ran. Here's the PR it opened — commits from the bot account, proper PR description, linked back to the Issue. No engineer wrote this.

*(Open the PR, show the Evaluator review comment)*

**Step 4 — The Review.**
And here's the Evaluator's review — it ran build, lint, tests, checked code quality across multiple dimensions, and posted its findings directly on the PR. It passed, so the Issue was labeled `approved`.

At this point, the engineer's only job is to read this and click Merge.

**From Issue to approved PR — two label clicks, zero lines of code written by a human.**

---

## Slide 11 · Roadmap (30 sec)

Looking ahead — three areas on the platform roadmap:

**Expanding patterns**: SAG for knowledge retrieval workflows, CAR for automated monitoring and reporting.

**Expanding integrations**: Jira full integration, Teams notifications, CloudWatch log monitoring, Bitbucket support.

**Improving the developer experience**: One-command onboarding script, better observability into what AI is doing, richer project context APIs.

The foundation is solid. We're expanding the surface area.

---

## Slide 12 · Thank You (30 sec)

That's the platform.

To summarize: **one shared hub, any team can onboard in 20 minutes, zero infrastructure to maintain, and engineers stay focused on decisions — not repetitive implementation work.**

The Quote team has been running this in production. The hub is the extracted, generalized version that's ready for any team to adopt.

**If your team wants to try it — or you just want to see how it would fit your specific setup — come find me after this session. I can walk you through exactly what onboarding would look like for your repo.**

Thank you.

---

## Timing Reference


| Slide     | Content                              | Target          |
| --------- | ------------------------------------ | --------------- |
| 1         | Cover — one-sentence pitch           | 30 sec          |
| 2         | The Problem                          | 1 min           |
| 3         | The Solution                         | 1 min           |
| 4         | Design Patterns (PGE/SAG/CAR)        | 45 sec          |
| 5         | API Layer — the developer experience | 1 min           |
| 6         | Flexible Adoption                    | 45 sec          |
| 7         | Onboarding in 20 minutes             | 45 sec          |
| 8         | Trigger Flow animation               | 1.5 min         |
| 9         | Current Status                       | 30 sec          |
| 10        | Live Demo                            | 2–3 min         |
| 11        | Roadmap                              | 30 sec          |
| 12        | Thank You + Call to Action           | 30 sec          |
| —         | Q&A                                  | 2 min           |
| **Total** |                                      | **≈ 11–13 min** |


---

## Delivery Tips

- **Slide 8 (Trigger Flow):** Slow down here — this is the densest slide. Let the animation play through before speaking to the next step. The visual does the work; your job is to narrate what's happening.
- **Slide 5 (API Layer):** Pause on the `uses:` line. Silence + one line of YAML makes the point better than explanation.
- **Demo (Slide 10):** Pre-load the Issue page in a browser tab before the session starts. Rehearse the scroll path — Issue → Planner comment → PR link → Evaluator review — so you don't fumble in front of the audience. No live actions needed; your job is purely to narrate what already happened.
- **Slides 2 & 9** tend to generate questions mid-slide. Don't stop — acknowledge ("great question, we'll hit that shortly") and keep moving. Address at Q&A.
- **Call to action:** Be specific. Don't say "reach out if interested" — say "come find me after this session and I'll show you exactly what onboarding looks like for your repo."
- **Aim for 10 minutes.** Leave the audience wanting more. A tight 10-minute presentation followed by a great Q&A is better than a 13-minute one that drags.

