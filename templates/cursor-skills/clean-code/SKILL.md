---
name: clean-code
description: Cross-repo clean-code baseline. Mandatory for every PR (Planner / Generator / Rework / Evaluator). Covers naming, function size, comments, complexity, duplication, error handling, and dependency boundaries. Layered ON TOP of each sub-project's development-standard/SKILL.md — never overrides domain rules.
---

# Clean Code Baseline (cross-repo)

This skill is a **non-negotiable baseline** for every milestone PR in this project,
regardless of sub-project. It must always appear in the Planner's `### Skills Referenced`
list and is enforced by the Evaluator's **Dimension G — Clean Code & Standard
Compliance**.

When this skill conflicts with a sub-project's `development-standard/SKILL.md`,
**the sub-project rule wins** (more specific). When the sub-project SKILL is silent,
this skill is binding.

---

## 1. Naming

| Rule | Detail |
|------|--------|
| **Intention-revealing** | A name must answer "why does this exist, what does it do, how is it used" without needing a comment. |
| **No 1–2 letter names** | Except loop counters (`i`, `j`) inside ≤5-line loops. No `d`, `tmp`, `data` for non-trivial values. |
| **No noise words** | Avoid `Manager`, `Processor`, `Helper`, `Util`, `Data`, `Info`, `Wrapper` unless the type really is a generic wrapper. Prefer the concrete role. |
| **No type-suffix doubling** | `userArray`, `userList`, `userMap` — drop the suffix unless the collection type is the meaningful distinguisher. |
| **Booleans read as predicates** | `isActive`, `hasPaid`, `canEdit`, `shouldRetry`. Never `flag`, `status` (for boolean), `active` (without is/has). |
| **Verbs for functions, nouns for values** | `calculateTotal()`, not `total()`. `fetchedQuote`, not `getQuote` (the variable). |
| **Searchable names** | If it appears in business logic, it must be greppable (`MAX_RETRY_COUNT`, not `3`). |
| **Avoid encodings** | No Hungarian (`strName`), no `I` prefix on TS interfaces **except** NestJS service interfaces (see engine `development-standard`). |

## 2. Functions

| Rule | Threshold |
|------|-----------|
| **Length** | ≤ 50 LOC including signature, blank lines, and `}`. Exception: pure data-shape mappers (DTO ↔ model). |
| **Parameters** | ≤ 4 positional. > 4 → wrap in an options object with a named TS interface. |
| **Cyclomatic complexity** | ≤ 10 per function. > 10 → extract guard clauses or helper functions. |
| **Nesting depth** | ≤ 3 levels of `if` / `for` / `try`. Use early-return guard clauses. |
| **Single level of abstraction** | A function either orchestrates other functions or does work — not both. |
| **No flag arguments** | `doThing(true)` — split into `doThing()` and `doThingWithSideEffect()`. |
| **No mutating arguments** | Treat all parameters as `readonly`. Return a new value instead. Exception: explicit out-parameters in performance-critical engine code (must be commented). |
| **Pure where possible** | Side-effects (network, disk, time, randomness, logging) should be isolated to dedicated functions / methods. |

## 3. Comments

> "A comment is a failure to express the intent in code."

| Allowed | Forbidden |
|---------|-----------|
| **Why** comments — non-obvious business rules, regulatory constraints, race-condition explanations | "What" comments — narrating what the next line does |
| Public API JSDoc on exported functions/classes from `packages/*` | `// Increment counter` style noise |
| `TODO(<owner>): <reason> (#<issue>)` | Bare `TODO`, `XXX`, `FIXME` without owner or issue link |
| Links to PRDs, RFCs, JIRA tickets that explain decisions | Commented-out code (delete it; use git history) |
| Performance / security trade-off notes | Redundant @param/@returns that just repeat the type |

## 4. Complexity & Duplication

- **Rule of three** — duplicate twice, extract on the third occurrence. Don't pre-abstract.
- **No magic numbers / strings** — extract to a `const` (in the engine, an `enum`).
- **No dead code** — delete commented-out code, unreachable branches, unused exports.
- **No `console.*` in production code paths** — use the project logger (`logger`, `this.logInfo`, etc.).
- **Avoid premature optimization** — write the clear version first; optimize only with a measured baseline.

## 5. Error Handling

- **Never swallow errors** — every `catch` must log via the project logger, re-throw, or convert to a typed error.
- **No bare `throw new Error("…")`** — use a project-typed error (`ApiError` in engine, mapped to `Response`/Zod issue in BFF).
- **Catch only what you can handle** — narrow the scope of `try` blocks. Don't wrap entire functions in `try`.
- **No `error: any` outside the catch binding** — see each sub-project's `development-standard/SKILL.md`.
- **Errors must include enough context** to diagnose without re-running the request (request id, key parameters, error code, upstream status).
- **Custom error base classes must use `new.target.prototype`** — when a base error class calls `Object.setPrototypeOf`, always use `new.target.prototype` (not the base class's own `.prototype`) so that `instanceof SubClass` checks remain correct for all subclasses. Using the base class prototype directly flattens the entire hierarchy and silently breaks `instanceof`-driven logic such as retry filters.

## 6. Async & Concurrency

- **No floating promises** — every promise is `await`ed, returned, or attached to `.catch()`. ESLint rule `@typescript-eslint/no-floating-promises` must pass.
- **No `await` inside `for` loops over independent items** — use `Promise.all` / `Promise.allSettled` (with concurrency cap if the upstream rate-limits).
- **Cancellation** — long-running BFF / engine work must respect the abort signal of the inbound request.
- **Idempotency** — any retried operation (write to upstream / payment / DB) must carry an idempotency key.

## 7. Boundaries & Dependencies

- **Inward dependency rule** — UI → server-side / BFF → API client → upstream. Reverse imports are forbidden.
- **No `..` climbing past the package root** — use the workspace alias (`@/`, `@novo/...`).
- **No circular imports** — break the cycle by extracting the shared piece into a leaf module.
- **One responsibility per file** — > 300 LOC of unrelated exports → split.

## 8. TypeScript Hygiene

- **No `any`** — see each sub-project's `development-standard/SKILL.md` for the only allowed exception (catch binding in the engine).
- **No `as` casts** unless paired with a runtime guard (Zod `.parse` / `class-validator` / `instanceof`).
- **No non-null assertion `!`** unless control-flow guarantees non-null on the same screen of code (preferred: optional chaining + fallback).
- **Discriminated unions over boolean flags** — `type Result = { kind: 'ok'; value: T } | { kind: 'err'; error: E }`.
- **`readonly` for immutable shapes** — props, config, frozen constants.
- **Explicit return types** on all exported functions.

## 9. Testing Hygiene

- **AAA layout** — Arrange, Act, Assert. Visually separated.
- **One behavior per test** — multiple `expect`s OK if they describe the same behavior.
- **No conditional assertions** — `if (cond) expect(...)` is a smell; split the test.
- **Test names describe behavior** — `it("returns 404 when quote is not found")`, not `it("test getQuote")`.
- **No shared mutable state** between tests — `beforeEach` resets fixtures.
- **Avoid mocking the system under test** — mock only external collaborators.
- **Snapshot tests sparingly** — only for stable structural output, never for prose.

## 10. Pull Request Hygiene

- **One concern per PR** — feature OR refactor OR docs OR infra. See `/.cursor/skills/refactor/SKILL.md` for the split rule.
- **Diff stays scoped** — touching unrelated files is a Dimension G violation unless explicitly justified in the PR body.
- **No drive-by reformatting** — formatting changes ride in their own PR (or are gated by Prettier on save). Avoid reflowing files you don't otherwise touch.
- **Self-review before requesting review** — read the diff yourself, prune debug logs, fix nits.
- **Linkable references** — every behavioral change references a SKILL section, an issue, or a Sprint Contract criterion.

## 11. Pre-merge Checklist (every PR)

- [ ] Function length / cyclomatic complexity within thresholds (§2)
- [ ] No magic numbers, no commented-out code, no `console.*` (§4)
- [ ] No floating promises, no `await` in independent-item loops (§6)
- [ ] No `any`, no unguarded `as`, no `!` (§8)
- [ ] Every error path logs with context (§5)
- [ ] No drive-by refactors mixed with feature changes (§10)
- [ ] `yarn lint` clean, build green, tests green
- [ ] Touched layers reflected in their `development-standard/SKILL.md` if a new pattern was introduced

## See Also

- `/.cursor/skills/refactor/SKILL.md` — when and how to refactor (companion baseline)
- Each sub-project's `development-standard/SKILL.md` for layer-specific rules:
  - `novo-portal-agent/.cursor/skills/development-standard/SKILL.md`
  - `novo-portal-agent/.cursor/skills/app-agent-portal/server/development-standard/SKILL.md`
  - `novo-portal-consumer/.cursor/skills/development-standard/SKILL.md`
  - `novo-quote-engine/.cursor/skills/development-standard/SKILL.md`
  - `novo-portal-ui-components/.cursor/skills/development-standard/SKILL.md`
  - `novo-portal-libs-analytics/.cursor/skills/development-standard/SKILL.md`
  - `novo-portal-libs-logging/.cursor/skills/development-standard/SKILL.md`
