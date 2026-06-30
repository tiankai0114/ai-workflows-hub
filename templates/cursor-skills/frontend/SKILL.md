---
name: frontend
description: Cross-repo frontend baseline for UI / client code (web, mobile-web, component libraries). Reference it from a PR whenever the diff touches components, pages, state, styling, forms, or client-side data fetching. Technology-neutral — applies to React, Vue, Svelte, Angular, or vanilla; a sub-project's development-standard/SKILL.md wins on framework-specific rules, this skill binds when it is silent.
---

# Frontend Baseline (cross-repo)

This skill is the **default quality bar for user-facing client code**. It is
framework-neutral: where it says "component" read your framework's unit of UI, where
it says "store" read your state container. When a sub-project's
`development-standard/SKILL.md` specifies a framework rule, that rule wins; when it is
silent, this skill binds.

It layers on top of `/.cursor/skills/clean-code/SKILL.md` (naming, function size,
error handling) — everything there still applies; this skill adds the UI-specific rules.

---

## 1. Component Design

| Rule | Detail |
|------|--------|
| **One responsibility per component** | A component either renders layout, owns state, or fetches data — not all three. Split container (data/logic) from presentational (props-in, markup-out). |
| **Props are the contract** | Type every prop. No untyped/`any` props. Required vs optional is explicit. Avoid > 6 props — group into an object or split the component. |
| **Composition over configuration** | Prefer `children` / slots over a growing list of boolean flags (`isLarge`, `withIcon`, `noBorder`). |
| **No business logic in markup** | Extract calculations and conditionals into named functions/hooks above the return. The template shows *what*, not *how*. |
| **Controlled by default** | Form inputs and interactive widgets are controlled (value + onChange) unless there is a measured reason to be uncontrolled. |
| **Stable keys** | List keys are stable domain ids, never the array index for reorderable/insertable lists. |

## 2. State Management

- **Minimize state** — derive whatever you can from existing state/props instead of storing a copy. Duplicate state is the #1 source of UI bugs.
- **Lift state only as high as needed** — co-locate state with the component that uses it; promote to a store only when genuinely shared.
- **Immutable updates** — never mutate state objects/arrays in place; produce new references so change detection works.
- **Single source of truth** — server data, URL, and local state must not disagree. Prefer the server/URL as the source; treat local copies as cache.
- **No derived state in effects** — compute during render; reserve effects for synchronizing with the outside world (DOM, network, subscriptions).

## 3. Data Fetching & Async UI

| Rule | Detail |
|------|--------|
| **Every async view models 4 states** | `loading` / `error` / `empty` / `success` — never render assuming data exists. |
| **No request waterfalls** | Independent requests run in parallel; only chain when one truly depends on another. |
| **Cancellation** | Cancel/ignore in-flight requests on unmount or when inputs change (abort signal / cleanup) to avoid setting state on a gone view. |
| **Cache & dedupe** | Use the project's data layer (query cache) rather than ad-hoc fetch-in-effect; dedupe identical concurrent requests. |
| **Error surfaces are actionable** | Show a retry affordance and a human message — never a raw stack trace or silent blank screen. |

## 4. Styling

- **Design tokens, not magic values** — colors, spacing, font sizes, radii, z-index come from the theme/token scale, never hardcoded hex or pixel literals scattered in components.
- **No inline style for anything themeable** — inline styles only for truly dynamic, computed values (e.g. a calculated transform).
- **Responsive by default** — layouts adapt; no fixed pixel widths that break on small screens. Test at the project's min supported width.
- **Co-locate styles with components** — and keep selector specificity low; avoid global overrides that leak across the app.
- **No z-index races** — z-index values come from a named scale, not escalating magic numbers.

## 5. Accessibility (a11y)

| Rule | Detail |
|------|--------|
| **Semantic HTML first** | Use `<button>`, `<a>`, `<nav>`, `<label>` etc. before reaching for `<div onClick>`. A clickable div needs role + key handlers — a button is free. |
| **Keyboard operable** | Every interactive element is reachable and operable by keyboard; visible focus state is preserved (never `outline: none` without a replacement). |
| **Labels & names** | Every input has an associated label; icon-only buttons have an accessible name (`aria-label`). |
| **Images** | Meaningful images have `alt`; decorative images have empty `alt`. |
| **Color is not the only signal** | Don't convey state by color alone; pair with text/icon. Meet contrast minimums (WCAG AA: 4.5:1 body text). |
| **Focus management** | Modals/dialogs trap focus, restore it on close, and are dismissible with `Esc`. |

## 6. Performance

- **Code-split at route/feature boundaries** — lazy-load heavy, non-critical screens; don't ship the whole app in one bundle.
- **Render only what's visible** — virtualize long lists; paginate large tables.
- **Memoize deliberately** — memoize expensive computations and stable callbacks, but don't wrap everything; premature memoization adds noise.
- **Avoid unnecessary re-renders** — stable references for props/context values; split large contexts so unrelated updates don't cascade.
- **Optimize assets** — responsive images, modern formats, lazy `loading`, and a watched bundle-size budget. Defer third-party scripts.
- **Measure, don't guess** — use the framework profiler / Lighthouse before and after a perf change.

## 7. Forms & Validation

- **Validate on the client for UX, on the server for trust** — never rely on client validation alone for correctness/security.
- **Inline, field-level errors** — show errors next to the field, on blur/submit, with a clear message; summarize at the top for screen readers.
- **Disable-and-indicate on submit** — prevent double submission; show progress; re-enable on completion/error.
- **Preserve user input on error** — never wipe a form because one field failed.

## 8. Client-side Security

| Rule | Detail |
|------|--------|
| **Treat all rendered data as untrusted** | Rely on the framework's auto-escaping. Avoid raw HTML injection (`dangerouslySetInnerHTML` / `v-html` / `innerHTML`); if unavoidable, sanitize with a vetted library. |
| **No secrets in the client** | API keys/tokens that grant privileged access never ship to the browser bundle. Public keys only. |
| **Validate URLs before navigation** | Guard against `javascript:` and open-redirects when navigating to user-supplied URLs. |
| **No sensitive data in `localStorage`** | Tokens/PII in web storage are XSS-exfiltratable; follow the project's auth-storage rule. |
| **Don't log PII** | Keep user data out of console/analytics breadcrumbs. |

## 9. Pre-merge Checklist (frontend PRs)

- [ ] Components are single-responsibility; no business logic embedded in markup (§1)
- [ ] No duplicated/derivable state; updates are immutable (§2)
- [ ] Async views handle loading / error / empty / success; requests are cancelled on unmount (§3)
- [ ] No hardcoded colors/spacing/z-index — tokens only (§4)
- [ ] Keyboard-operable, labelled, sufficient contrast, focus visible (§5)
- [ ] No obvious re-render/bundle regressions; heavy screens code-split (§6)
- [ ] Server-side validation exists for anything security/correctness-sensitive (§7)
- [ ] No raw HTML injection, no secrets/PII in the client (§8)

## See Also

- `/.cursor/skills/clean-code/SKILL.md` — universal quality baseline (applies first)
- `/.cursor/skills/api-design/SKILL.md` — the contract this client consumes
- `/.cursor/skills/testing/SKILL.md` — component/interaction testing
- `/.cursor/skills/security/SKILL.md` — full security baseline
- The sub-project's `development-standard/SKILL.md` for framework-specific rules
