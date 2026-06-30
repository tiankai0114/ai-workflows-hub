---
name: backend
description: Cross-repo backend baseline for server-side code (APIs, services, workers, jobs). Reference it from a PR whenever the diff touches controllers, services, repositories, data access, auth, or background jobs. Technology-neutral — applies to Node/NestJS, Go, Java/Spring, Python, etc.; a sub-project's development-standard/SKILL.md wins on framework-specific rules, this skill binds when it is silent.
---

# Backend Baseline (cross-repo)

This skill is the **default quality bar for server-side code**. It is language- and
framework-neutral: where it says "service" read your unit of business logic, where it
says "repository" read your data-access layer. A sub-project's
`development-standard/SKILL.md` wins on specific rules; this skill binds when it is silent.

It layers on top of `/.cursor/skills/clean-code/SKILL.md` (naming, function size,
async/error handling) — everything there still applies; this skill adds server-specific rules.

---

## 1. Layering & Boundaries

| Layer | Responsibility | Must NOT |
|-------|----------------|----------|
| **Controller / handler** | Parse + validate input, map to a use-case call, shape the response | Contain business rules or talk to the DB directly |
| **Service / use-case** | Business logic, orchestration, transactions | Know about HTTP (no req/res), build SQL strings |
| **Repository / data access** | Persistence, queries, mapping rows ↔ domain | Contain business decisions |

- **Dependency direction is inward** — controller → service → repository. Never the reverse; never skip a layer to query the DB from a controller.
- **No framework types leaking across layers** — the HTTP request object stops at the controller; the ORM entity stops at the repository (map to a domain type).

## 2. Input Validation (trust nothing from the wire)

- **Validate at the boundary** — every inbound payload, query param, header, and path param is validated against a schema before use.
- **Whitelist, don't blacklist** — accept known-good shapes; reject everything else with a 4xx, not a 500.
- **Validate types AND constraints** — not just "is a string" but length, range, enum membership, format.
- **Never trust client-supplied ids for authorization** — re-check ownership server-side (see §7 — IDOR).

## 3. Error Handling

| Rule | Detail |
|------|--------|
| **Typed errors, not bare throws** | Throw domain/typed errors (`NotFoundError`, `ValidationError`) and map them centrally to status codes. |
| **One central error mapper** | A single middleware/filter converts errors to the API error envelope (see api-design). No ad-hoc `res.status(500)` scattered around. |
| **Never leak internals** | No stack traces, SQL, or upstream raw errors in responses. Log them server-side with a correlation id; return a safe message + code. |
| **Distinguish client vs server faults** | 4xx for caller mistakes (don't alert/retry), 5xx for our faults (alert). |
| **Fail fast on misconfiguration** | Missing required config/env at boot → crash on startup, not on first request. |

## 4. Data Access

- **Use transactions for multi-write operations** — a logical unit that writes ≥ 2 rows/tables is atomic; partial writes are a bug.
- **Avoid N+1 queries** — batch/join/eager-load; never query inside a loop over rows.
- **Parameterized queries only** — never string-concatenate user input into SQL/NoSQL queries (injection — see security).
- **Migrations are versioned and reversible** — schema changes ship as migrations, never manual edits; backward-compatible (expand/contract) for zero-downtime deploys.
- **Bound every query** — list endpoints always paginate; no unbounded `SELECT *` that can return millions of rows.
- **Connection pooling** — reuse pooled connections; don't open per-request connections.

## 5. Concurrency & Idempotency

- **Idempotent writes** — any operation that may be retried (payment, external POST, queue consumer) carries an idempotency key and is safe to run twice.
- **Guard against race conditions** — use DB constraints / optimistic locking / `SELECT ... FOR UPDATE` for read-modify-write on shared rows; don't rely on app-level check-then-act.
- **Background work respects cancellation/timeouts** — long jobs are interruptible and have a max runtime.
- **Parallelize independent I/O** — fan-out independent calls; don't `await` them sequentially.

## 6. Logging & Observability

| Rule | Detail |
|------|--------|
| **Structured logs** | Log JSON (or the project format) with fields, not string concatenation. Use the project logger, never `print`/`console.log`. |
| **Correlation id on every log** | Propagate a request/trace id through the call chain so one request's logs are linkable. |
| **Right level** | `error` = needs attention, `warn` = recoverable anomaly, `info` = lifecycle, `debug` = dev only (off in prod). No debug logging left in hot paths. |
| **Never log secrets/PII** | Tokens, passwords, full PANs, personal data are redacted before logging. |
| **Emit metrics for SLOs** | Latency, error rate, throughput on key endpoints; health/readiness probes for orchestration. |

## 7. Security (server-side essentials)

- **Authenticate then authorize** — verify identity, then check that *this* user may act on *this* resource. Re-check ownership on every object access (prevent IDOR).
- **Least privilege** — service credentials/DB roles/cloud IAM grant only what's needed.
- **Secrets from a manager, never in code or repo** — injected via env/secret store; rotated; never logged.
- **Rate-limit and size-limit** — cap request body size and per-client request rate on public endpoints.
- **See `/.cursor/skills/security/SKILL.md`** for the full baseline (injection, crypto, dependencies).

## 8. Configuration

- **12-factor config** — all environment-specific values come from env/secret store, not hardcoded or committed.
- **Validate config at startup** — parse env into a typed, validated config object once; fail fast if invalid/missing.
- **No environment branching in business logic** — inject behavior via config/flags, don't sprinkle `if (env === 'prod')` through the code.

## 9. Pre-merge Checklist (backend PRs)

- [ ] Layer boundaries respected; no DB access from controllers, no HTTP types in services (§1)
- [ ] All inbound input validated against a schema at the boundary (§2)
- [ ] Errors are typed + centrally mapped; no internals leaked; 4xx vs 5xx correct (§3)
- [ ] Multi-write ops are transactional; no N+1; queries parameterized + bounded (§4)
- [ ] Retryable operations are idempotent; shared-row writes guarded (§5)
- [ ] Structured logs with correlation id; no secrets/PII logged; key metrics emitted (§6)
- [ ] AuthN + per-object AuthZ enforced; least privilege; secrets from a manager (§7)
- [ ] Config validated at startup; no hardcoded env values (§8)

## See Also

- `/.cursor/skills/clean-code/SKILL.md` — universal quality baseline (applies first)
- `/.cursor/skills/api-design/SKILL.md` — the HTTP contract this code exposes
- `/.cursor/skills/security/SKILL.md` — full security baseline
- `/.cursor/skills/testing/SKILL.md` — unit/integration testing of services
- The sub-project's `development-standard/SKILL.md` for framework-specific rules
