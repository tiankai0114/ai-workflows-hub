---
name: testing
description: Cross-repo testing baseline. Reference it from any PR that adds or changes behavior — tests are part of the change, not a follow-up. Covers the test pyramid, unit/integration/e2e scope, test doubles, coverage philosophy, determinism (no flaky tests), and test data. Technology-neutral; a sub-project's development-standard/SKILL.md wins on tool-specific rules (runner, assertion lib).
---

# Testing Baseline (cross-repo)

This skill defines **what to test, at what level, and how to keep the suite trustworthy**.
It expands clean-code §9 (Testing Hygiene) into a full strategy. A sub-project's
`development-standard/SKILL.md` wins on tool specifics (which runner, mocking lib,
coverage thresholds); this skill binds when it is silent.

Core principle: **a test exists to let you change code with confidence.** A test that is
flaky, untrustworthy, or coupled to implementation details is worse than no test.

---

## 1. The Test Pyramid

| Level | What it covers | Proportion | Speed |
|-------|----------------|-----------|-------|
| **Unit** | A function/class/component in isolation | Most | ms |
| **Integration** | A few units + a real collaborator (DB, HTTP layer) | Some | 10s–100s ms |
| **End-to-end** | A full user flow through the running system | Few | seconds |

- **Push tests down the pyramid** — prefer the cheapest level that gives real confidence. Don't e2e-test what a unit test can prove.
- **Every behavioral change ships with the test that proves it** — in the same PR. Bug fixes ship with a regression test that fails before the fix.

## 2. Unit Tests

- **AAA layout** — Arrange, Act, Assert, visually separated.
- **One behavior per test** — multiple `expect`s are fine only if they describe the same behavior.
- **Behavioral names** — `it("returns 404 when the quote does not exist")`, not `it("test getQuote")`.
- **No conditional logic in tests** — no `if`/`for`/`try` deciding what to assert; that's a sign the test should be split or parameterized.
- **Test behavior, not implementation** — assert on observable outputs/effects, not private internals or call counts of internal helpers. Refactors must not break correct tests.
- **Cover the edges** — empty, null/undefined, boundary values, error paths — not just the happy path.

## 3. Test Doubles (mocks, stubs, fakes)

| Do | Don't |
|----|-------|
| Mock **external collaborators** (network, DB, clock, randomness, third-party SDKs) | Mock the **system under test** itself |
| Use a **fake/in-memory** implementation for repositories where practical | Over-mock until the test only verifies your mocks |
| Assert on the **outcome**, fall back to interaction checks only for side-effect-only collaborators | Assert exact internal call sequences that lock in implementation |
| Reset/restore all doubles in `afterEach` | Leak mock state across tests |

- **Control time and randomness** — inject/freeze the clock and seed RNG so results are deterministic.

## 4. Integration Tests

- **Test across a real boundary** — service + real DB (test container/in-memory), or controller + real validation/serialization — to catch wiring bugs units miss.
- **Isolated, disposable state** — each test sets up and tears down its own data; tests never depend on order or shared rows.
- **Cover the contract** — for an API, assert status code, response shape, and error envelope (see api-design), not just the happy 200.

## 5. End-to-End Tests

- **Reserve for critical user journeys** — login, checkout, the core happy path — not every permutation.
- **Stable selectors** — target `data-testid`/roles, not CSS classes or DOM structure that churns.
- **Keep them few and fast** — they're the most expensive and most fragile; an e2e suite that's slow/flaky gets ignored.

## 6. Coverage Philosophy

- **Coverage is a smoke detector, not a goal** — high coverage of meaningless assertions proves nothing.
- **Cover behavior and risk** — prioritize branches with business/financial/security impact and historically buggy areas.
- **No assertion-free tests** — a test that runs code without asserting an outcome only inflates the number.
- **Respect the project threshold** but never game it (e.g. testing getters to hit a percentage).

## 7. Reliability (zero-flake policy)

- **Deterministic** — no dependence on wall-clock time, real network, current locale/timezone, or random order. Pin them.
- **No `sleep`-based waits** — wait for a condition/event, not an arbitrary duration.
- **Independent & parallel-safe** — no shared mutable state; `beforeEach` resets fixtures; tests pass in any order and in parallel.
- **A flaky test is a bug** — quarantine or fix immediately; never retry-loop a flaky test to green and merge.

## 8. Test Data

- **Factories/builders over copy-pasted literals** — create domain objects via a builder with sensible defaults and per-test overrides.
- **Minimal & intention-revealing** — the test only sets the fields relevant to the behavior under test; everything else is a default.
- **No production data / real PII** in fixtures.

## 9. Pre-merge Checklist (any behavioral PR)

- [ ] New/changed behavior is covered at the lowest sufficient level (§1)
- [ ] Bug fix includes a regression test that fails without the fix (§1)
- [ ] Tests follow AAA, one behavior each, behavioral names (§2)
- [ ] Only external collaborators are mocked; SUT is not mocked; time/RNG controlled (§3)
- [ ] Assertions are on behavior/outputs, not private internals (§2)
- [ ] Tests are deterministic, independent, parallel-safe — no flakes, no `sleep` (§7)
- [ ] Test data via factories; no real PII (§8)
- [ ] Suite is green locally and in CI

## See Also

- `/.cursor/skills/clean-code/SKILL.md` §9 — testing hygiene (the seed of this skill)
- `/.cursor/skills/refactor/SKILL.md` — the Green → Refactor → Green safety net
- `/.cursor/skills/api-design/SKILL.md` — what integration tests assert against
- The sub-project's `development-standard/SKILL.md` for runner/tooling specifics
