---
name: refactor
description: Cross-repo refactor playbook. Mandatory for every PR (Planner / Generator / Rework / Evaluator). Defines when to refactor vs leave alone, the safe-net protocol, supported techniques, PR splitting, and forbidden anti-patterns. Layered ON TOP of each sub-project's development-standard/SKILL.md.
---

# Refactor Playbook (cross-repo)

This skill is the **non-negotiable refactor protocol** for this project. It must
always appear in the Planner's `### Skills Referenced` list and is enforced by the
Evaluator's **Dimension G — Clean Code & Standard Compliance** together with
`/.cursor/skills/clean-code/SKILL.md`.

The two skills are companions:
- **clean-code** — describes the steady-state quality bar.
- **refactor** — describes how to *change* code toward that bar safely.

---

## 1. Mental Model

**Refactor = behavior-preserving structural change.** If observable behavior changes,
it is not a refactor — it is a feature change or a bug fix and must be split into
its own PR (see §6).

The only sanctioned reasons to refactor:

| Trigger | Example |
|--------|---------|
| **Rule of three** | The same shape appears for the third time → extract. |
| **Imminent change** | A new feature lands on top of confusing code → clean *just* what the feature touches. |
| **Bug-fix preparation** | Bug is hard to locate because of nesting / duplication → flatten then fix. |
| **Pre-existing standard violation** | Touched file violates clean-code §2/§4/§8 thresholds → bring it back into compliance. |
| **Performance hot-path** | Profiling shows a real cost → refactor with a measured baseline. |

## 2. When NOT to Refactor

- **No tests covering the area.** Add characterization tests first; never refactor "blind".
- **Code is volatile and about to be deleted.** Don't polish a file scheduled for removal.
- **Cross-cutting design rewrite** without an issue / RFC. Refactors that change architecture (layer ownership, contract shape, package boundaries) need an issue and a planner pass.
- **Mid-feature commit.** Don't refactor in the same milestone as a behavioral change unless the refactor is literally the prerequisite (then split — see §6).
- **You don't fully understand the code.** Read it, write a characterization test, then refactor.

## 3. The Safety Net (mandatory)

Every refactor follows the **Green → Refactor → Green** loop:

1. **Green** — confirm the relevant tests (`yarn lint`, `npx vitest --run`, `yarn build`,
   engine `yarn test`) all pass on the current code. If a behavior is uncovered, write a
   *characterization test* first that pins down the existing behavior — even if the
   behavior is wrong (a separate PR will fix it).
2. **Refactor** — apply ONE small step at a time (Extract Method, Inline Variable,
   Move Function, Rename, Replace Conditional with Polymorphism, …). Run tests after
   each step.
3. **Green** — same verification suite must still pass. Then commit.

> **Never commit a refactor with red tests.** Roll back the step instead.

## 4. Supported Techniques

The catalog below lists techniques routinely safe inside this repo. For each, the
"safety net" column says what protects you from regressions.

| Technique | When to use | Safety net |
|-----------|-------------|------------|
| **Extract Function** | Function exceeds clean-code §2 thresholds; same expression appears twice | Existing unit tests + lint |
| **Inline Function/Variable** | Indirection adds no clarity | Existing tests |
| **Rename** | Name no longer reflects intent (clean-code §1) | Lint + tsc + tests + IDE rename across workspace |
| **Move Function/File** | Function lives in the wrong layer / package | tsc + lint (paths) + tests |
| **Replace Conditional with Polymorphism** | Long `switch`/`if-else` on a discriminator | Tests per branch |
| **Replace Magic Number with Constant** | clean-code §4 violation | Tests + grep for the literal |
| **Replace Loop with Pipeline** | Imperative loop doing map/filter/reduce | Tests |
| **Split Phase** | A function mixes parsing + business logic | Tests per phase |
| **Encapsulate Variable** | Mutable global / module-level state | Tests + grep for direct access |
| **Replace Primitive with Object/Type** | A primitive carries domain meaning (e.g. `string` for `QuoteId`) | Tests + tsc strictness |
| **Combine/Split Module** | Files exceed §7 size or have multiple unrelated responsibilities | tsc + lint + tests |

Avoid grand techniques (Strangler Fig, Branch by Abstraction) without a tracking
issue and a Planner pass — they are multi-PR programs, not refactors.

## 5. Anti-patterns (forbidden in this repo)

| Anti-pattern | Why it's banned | Do this instead |
|--------------|----------------|-----------------|
| **Drive-by refactor** in a feature PR | Inflates diff, hides regressions, confuses reviewers | Split into pre-/post-feature refactor PR |
| **Big-bang rewrite** without tests | Untested path → behavior drift; reviewers can't tell what's intentional | Add characterization tests, then incremental moves |
| **Rename + reformat in the same commit as a behavior change** | Diff hides the behavior change | Two commits, ideally two PRs |
| **Renaming exported symbols across packages without a deprecation alias** | Breaks downstream consumers without warning | Add export alias + deprecation comment, remove alias in a follow-up PR |
| **Changing public DTO / Zod schema shape "while I'm here"** | Breaks contract; surprises Evaluator | Bump the contract intentionally, update SKILL files, add migration note |
| **Introducing a new abstraction "for the future"** | Speculative; usually wrong | Wait for the rule-of-three; YAGNI |
| **Removing tests because they "no longer apply"** | The behavior was real; tests need to change *with* the refactor or in lockstep | Update tests in the same commit; explain in the PR body |

## 6. PR Splitting

Each PR has exactly one concern. The split rules:

- **Refactor PR** — diff is behavior-preserving; tests are unchanged or only renamed/restructured. PR title: `refactor(<scope>): <what>`. Body cites the trigger from §1.
- **Feature PR** — adds/changes behavior; tests change accordingly. Lands *after* any prerequisite refactor PR.
- **Bug-fix PR** — minimal change to fix a defect; adds the regression test. No incidental refactors.
- **Docs/SKILL PR** — only `*.md` and SKILL files. No code.
- **Infra/CI PR** — only `.github/`, `Dockerfile`, `Helm/`, `jenkins.yaml`, `vercel.ts`, etc.

If a milestone genuinely needs both refactor and feature work, the Planner must
issue them as **two milestones in order**: refactor first, feature second.
Skipping this and bundling them is a Dimension G violation.

## 7. Cross-cutting Refactor Protocol

When a refactor crosses package boundaries (e.g. renaming an export shared by
agent and consumer), follow this protocol:

1. **Plan**: open or update a tracking issue. List every consumer.
2. **Add the new symbol** alongside the old. Mark the old as `@deprecated` with the
   removal target (issue #N or a milestone).
3. **Migrate consumers** one PR at a time. Each migration PR keeps the old API alive.
4. **Remove the deprecated symbol** in a final PR after every consumer is migrated.
5. **Update SKILL files** in the same PR as the removal — every `development-standard/SKILL.md`,
   any domain SKILL that referenced the old name, and the root `CLAUDE.md` index if needed.

Skipping the deprecation alias is a Dimension G violation unless the symbol is only
used inside the same package (verify with workspace-wide grep).

## 8. Refactor PR Body Template

```markdown
## Why
- Trigger from `/.cursor/skills/refactor/SKILL.md` §1: <rule of three / imminent change / …>
- Concrete pain (file:line): <quote the smell>

## What changed
- Technique applied: <Extract Method / Move File / …>
- Behavior preserved: <list the tests that prove this>

## What did NOT change
- Public API of <package> is unchanged
- Observable behavior of <feature> is unchanged

## Verification
- [ ] `yarn lint` clean
- [ ] `yarn build` green
- [ ] `npx vitest --run` (agent / consumer) green
- [ ] `yarn test` (engine) green
- [ ] Storybook builds (UI components only)
- [ ] No new SKILL update required (cite reason) OR list updated SKILLs
```

## 9. Pre-merge Checklist

- [ ] PR is exclusively a refactor (no behavior change). If false → split.
- [ ] Trigger from §1 is named in the PR body.
- [ ] No technique from §5 is present.
- [ ] Tests are unchanged (or only renamed/restructured / characterization tests added).
- [ ] Cross-cutting renames followed §7 (deprecation alias).
- [ ] All SKILL files referencing the moved/renamed symbol updated in the same PR.
- [ ] Diff is small enough to review in one sitting (target: < 400 LOC; > 800 LOC requires Planner sign-off).

## See Also

- `/.cursor/skills/clean-code/SKILL.md` — what "good" looks like (the destination)
- Each sub-project's `development-standard/SKILL.md` for layer-specific patterns
