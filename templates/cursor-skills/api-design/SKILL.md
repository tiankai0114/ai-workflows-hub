---
name: api-design
description: Cross-repo API contract baseline for HTTP/REST-style APIs. Reference it from a PR whenever the diff adds or changes an endpoint, request/response shape, status code, error format, or public schema. Protocol guidance is REST-first but the principles (versioning, errors, pagination, idempotency, backward compatibility) apply to RPC/GraphQL too.
---

# API Design Baseline (cross-repo)

This skill defines the **contract rules** for APIs this project exposes or consumes.
A clear, stable, predictable contract is what lets frontend and backend evolve
independently. A sub-project's `development-standard/SKILL.md` wins on specific
conventions (envelope shape, casing); this skill binds when it is silent.

It pairs with `/.cursor/skills/backend/SKILL.md` (how the server implements the
contract) and `/.cursor/skills/frontend/SKILL.md` (how the client consumes it).

---

## 1. Resources & URLs

| Rule | Example |
|------|---------|
| **Nouns, not verbs** | `POST /orders`, not `POST /createOrder`. The HTTP method is the verb. |
| **Plural collections** | `/users`, `/users/{id}`, `/users/{id}/orders`. |
| **Hierarchy reflects ownership** | Nest only for true containment; cap nesting at ~2 levels. Deep relations use query params or links. |
| **Lowercase, hyphenated paths** | `/payment-methods`, not `/paymentMethods` or `/payment_methods`. |
| **No trailing action verbs** | Prefer sub-resources/state changes over `/orders/{id}/cancel` where a `PATCH` on status fits; use action endpoints only for genuine non-CRUD commands. |

## 2. Methods & Status Codes

| Method | Semantics | Idempotent? |
|--------|-----------|-------------|
| `GET` | Read; never has side effects | Yes |
| `POST` | Create / non-idempotent command | No |
| `PUT` | Full replace | Yes |
| `PATCH` | Partial update | No (unless designed to be) |
| `DELETE` | Remove | Yes |

Use status codes truthfully:
- **200** OK, **201** Created (+ `Location`), **202** Accepted (async), **204** No Content.
- **400** validation, **401** unauthenticated, **403** unauthorized, **404** not found, **409** conflict, **422** semantic validation, **429** rate-limited.
- **500** our fault, **503** dependency down. Never return `200` with an error body.

## 3. Request & Response Shapes

- **JSON by default**, `Content-Type: application/json`, UTF-8.
- **Consistent casing** — pick `camelCase` or `snake_case` once, project-wide; never mix.
- **Stable, typed shapes** — responses are documented and validated; no "sometimes this field is a string, sometimes an array".
- **Don't expose internals** — return DTOs, not raw DB rows; omit internal flags, soft-delete columns, internal ids.
- **Timestamps are ISO-8601 UTC** (`2026-06-30T12:00:00Z`); money is integer minor units (or a typed decimal), never a float.
- **Booleans and enums, not magic strings** — enumerate allowed values explicitly.

## 4. Error Format (one envelope everywhere)

Every error response shares one shape so clients can handle it generically:

```json
{
  "error": {
    "code": "ORDER_NOT_FOUND",
    "message": "Human-readable, safe to surface",
    "details": [{ "field": "quantity", "issue": "must be >= 1" }],
    "requestId": "req_01H..."
  }
}
```

- **Machine-readable `code`** drives client logic; `message` is for humans/logs.
- **`details`** lists field-level validation problems for 400/422.
- **`requestId`** correlates the response with server logs.
- **Never leak** stack traces, SQL, internal hostnames, or upstream raw errors.

## 5. Versioning & Compatibility

- **Version the API** — `/v1/...` in the path (or a header) before the first external consumer.
- **Backward-compatible changes are free**: adding optional fields, adding endpoints, adding enum values clients are told to tolerate.
- **Breaking changes require a new version**: removing/renaming a field, tightening validation, changing a type, changing status-code semantics.
- **Deprecate, don't delete** — mark deprecated fields/endpoints, announce a sunset date, keep them alive through the migration window, then remove in a bumped version.
- **Tolerant reader** — clients ignore unknown fields rather than breaking.

## 6. Pagination, Filtering, Sorting

- **All list endpoints paginate** — never return an unbounded collection. Default + max page size are documented.
- **Cursor pagination for large/changing sets** (`?cursor=...&limit=...`); offset pagination only for small, stable lists.
- **Consistent query params** — `filter[...]`, `sort=-createdAt`, `limit`, `cursor` — same names across endpoints.
- **Return paging metadata** — total/next-cursor so clients can fetch the next page deterministically.

## 7. Idempotency & Concurrency

- **`Idempotency-Key` on unsafe creates** — `POST` that creates a resource accepts an idempotency key so retries don't double-charge/double-create.
- **Optimistic concurrency** — use `ETag` + `If-Match` (or a `version` field) on updates to detect lost updates; return `409`/`412` on conflict.
- **Document idempotency semantics** for every mutating endpoint.

## 8. Auth, Limits & Headers

- **Auth scheme is consistent** — `Authorization: Bearer <token>` (or the project standard) on every protected endpoint; document required scopes/roles.
- **Rate limits are communicated** — `429` + `Retry-After`; expose limit headers where applicable.
- **Cap payload size** — document and enforce a max request body.
- **CORS is explicit** — allowed origins are a whitelist, never `*` for credentialed endpoints.

## 9. Documentation

- **Spec is the source of truth** — every endpoint is described in OpenAPI/Swagger (or the project's IDL) and kept in sync with code in the same PR.
- **Examples for request + response + each error** — including the error envelope.
- **Changelog** — breaking and notable changes recorded per version.

## 10. Pre-merge Checklist (API PRs)

- [ ] Resource-oriented URL, correct method + status codes (§1–§2)
- [ ] Consistent casing; DTOs (not raw rows); no leaked internals (§3)
- [ ] Errors use the single envelope with `code` + `requestId`; no internals leaked (§4)
- [ ] Change is backward-compatible OR a version bump + deprecation plan (§5)
- [ ] List endpoints paginate with documented limits (§6)
- [ ] Unsafe creates accept an idempotency key; updates guard concurrency (§7)
- [ ] Auth, rate-limit, body-size, and CORS rules applied (§8)
- [ ] OpenAPI/spec + examples updated in the same PR (§9)

## See Also

- `/.cursor/skills/backend/SKILL.md` — server-side implementation of this contract
- `/.cursor/skills/frontend/SKILL.md` — client-side consumption of this contract
- `/.cursor/skills/security/SKILL.md` — auth, input validation, transport security
- The sub-project's `development-standard/SKILL.md` for project-specific conventions
