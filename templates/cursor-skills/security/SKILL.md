---
name: security
description: Cross-repo security baseline (OWASP-aligned). Reference it from any PR that handles untrusted input, authentication, authorization, secrets, crypto, file uploads, or dependencies. Mandatory consideration for any code on a network boundary. Technology-neutral; a sub-project's development-standard/SKILL.md may add stricter rules, never looser.
---

# Security Baseline (cross-repo)

This skill is the **minimum security bar** for code that touches untrusted input,
identity, or secrets. It is OWASP-aligned and intentionally practical. A sub-project's
`development-standard/SKILL.md` may add stricter rules; it may never relax these.

Security is not a separate phase — it is a property of every PR. When in doubt, treat
input as hostile and grant the least privilege that works.

It pairs with `/.cursor/skills/backend/SKILL.md`, `/.cursor/skills/frontend/SKILL.md`,
and `/.cursor/skills/api-design/SKILL.md`.

---

## 1. Input Validation & Output Encoding (injection)

| Threat | Rule |
|--------|------|
| **SQL / NoSQL injection** | Parameterized queries / prepared statements only. Never concatenate user input into a query. ORMs must use bound params, not raw interpolation. |
| **Command injection** | Never pass user input to a shell. Use argument arrays / safe APIs; if a shell is unavoidable, strict allow-list validation. |
| **XSS** | Rely on the framework's auto-escaping. Avoid raw HTML sinks (`innerHTML`, `dangerouslySetInnerHTML`, `v-html`); sanitize with a vetted library if unavoidable. |
| **Path traversal** | Resolve and validate user-supplied paths against an allowed base dir; reject `..` and absolute paths. |
| **SSRF** | Don't fetch arbitrary user-supplied URLs; allow-list hosts/schemes; block internal IP ranges and metadata endpoints. |
| **Deserialization** | Never deserialize untrusted data into executable types; validate against a schema. |

- **Validate at the boundary, whitelist not blacklist** (see backend §2): length, type, range, format, enum membership.

## 2. Authentication

- **Don't roll your own** — use a vetted library/provider for auth and session handling.
- **Hash passwords with a slow, salted KDF** — bcrypt/scrypt/argon2id. Never MD5/SHA-1, never plaintext, never reversible encryption for passwords.
- **Sessions/tokens** — short-lived access tokens + rotating refresh; invalidate on logout/password change; secure, `HttpOnly`, `SameSite` cookies for web sessions.
- **Throttle auth endpoints** — rate-limit login/reset; lock or back-off on repeated failures; generic error messages (don't reveal which of username/password was wrong).
- **MFA where the project requires it** for privileged actions.

## 3. Authorization

- **Authorize every request, server-side** — never trust the client to hide a button.
- **Check object ownership on every access (prevent IDOR)** — `GET /orders/{id}` must verify the order belongs to the caller, not just that they're logged in.
- **Least privilege & deny-by-default** — start from no access; grant explicitly. Roles/scopes are checked, not assumed.
- **No privilege decisions from client-supplied role/flags** — derive authority from the verified identity server-side.

## 4. Secrets Management

| Rule | Detail |
|------|--------|
| **No secrets in code or git** | API keys, passwords, private keys, tokens never committed. Scan for them in CI; rotate immediately if leaked. |
| **From env / secret manager** | Injected at runtime; never baked into images or client bundles. |
| **Rotate & scope** | Secrets are rotatable and scoped to least privilege; short-lived/federated credentials (e.g. OIDC) over long-lived keys. |
| **Never log secrets** | Redact tokens/passwords/PII before logging (see backend §6). |

## 5. Cryptography & Data Protection

- **Use standard, modern algorithms** via vetted libraries — never hand-roll crypto. AES-GCM / ChaCha20-Poly1305 for symmetric, TLS 1.2+ for transport.
- **Encrypt in transit and at rest** — HTTPS everywhere; encrypt sensitive data and backups at rest.
- **Generate randomness securely** — CSPRNG for tokens/ids/keys, never `Math.random()` for anything security-relevant.
- **Minimize and classify PII** — collect the minimum; know where PII lives; mask it in logs, errors, and analytics; honor retention/deletion rules.

## 6. Dependencies & Supply Chain

- **Pin and lock** — commit lockfiles; reproducible installs.
- **Scan continuously** — dependency vulnerability scanning in CI (e.g. audit / SCA); triage and patch known-vuln packages.
- **Vet new dependencies** — prefer maintained, popular libraries; avoid pulling a whole framework for a one-liner.
- **Verify integrity** — use trusted registries; be wary of typosquats; pin actions/images by version or digest.

## 7. Errors, Logging & Headers

- **Fail safe** — on error, deny access; don't fall through to an open state.
- **No information leakage** — generic error messages to clients; no stack traces, versions, internal hostnames, or SQL in responses (see backend §3).
- **Security headers** (web) — `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, frame-ancestors / `X-Frame-Options`.
- **Audit-log security events** — auth failures, privilege changes, access to sensitive data — with correlation ids, without logging the sensitive data itself.

## 8. Common Boundaries

- **File uploads** — validate type/size, store outside the web root, generate server-side filenames, scan if required, never execute uploaded content.
- **CORS** — explicit origin allow-list; never `*` with credentials.
- **Rate limiting & request size caps** on all public endpoints (DoS protection).
- **CSRF** — anti-CSRF tokens / `SameSite` cookies for state-changing form requests.

## 9. Pre-merge Checklist (security-relevant PRs)

- [ ] All untrusted input validated; queries parameterized; output encoded; no raw HTML/shell sinks (§1)
- [ ] Passwords hashed with argon2/bcrypt/scrypt; sessions/tokens handled by a vetted lib; auth endpoints throttled (§2)
- [ ] Every request authorized server-side; object ownership checked (no IDOR); least privilege (§3)
- [ ] No secrets in code/git; loaded from env/secret manager; not logged (§4)
- [ ] Standard crypto via libraries; TLS in transit; sensitive data encrypted at rest; CSPRNG for tokens (§5)
- [ ] Lockfile committed; dependency scan clean / triaged (§6)
- [ ] Errors fail safe and leak nothing; security headers set; security events audit-logged (§7)
- [ ] Uploads/CORS/CSRF/rate-limits handled where applicable (§8)

## See Also

- `/.cursor/skills/backend/SKILL.md` — server-side auth, validation, logging
- `/.cursor/skills/frontend/SKILL.md` — client-side XSS, secret, storage rules
- `/.cursor/skills/api-design/SKILL.md` — auth scheme, CORS, rate-limit contract
- OWASP Top 10 and OWASP ASVS for the authoritative, evolving reference
- The sub-project's `development-standard/SKILL.md` for stricter project rules
