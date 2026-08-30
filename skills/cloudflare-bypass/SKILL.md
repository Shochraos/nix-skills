---
name: cloudflare-bypass
description: Use when `read`, `browser`, or `web_search` hits a Cloudflare challenge (Turnstile/Interstitial), a "Verifying you are human" page, a 403/503 block, a timeout, or any anti-bot wall while fetching a URL — OR when `read` returns an empty/stub shell (bare `<div id="root">`, a bare "Moved to <url>" redirect stub, a loading spinner, or a title/meta block with no body text) because the page is a client-side-rendered JS single-page app. Routes the fetch through the Scrapling MCP server instead of retrying the same blocked or unrendered path.
---

# Cloudflare / anti-bot bypass & JS-SPA rendering via Scrapling MCP

`read`'s reader-mode fetch, `web_search`, and the `browser` tool's puppeteer stealth
patches can still get stopped by Cloudflare Turnstile/Interstitial, Akamai, or similar
anti-bot walls — and separately, `read` does not execute JavaScript, so
client-side-rendered SPAs (React/Vue/Angular apps, in-browser calculators, dashboards)
come back as an empty shell instead of real content. In both cases, don't retry the
same blocked or unrendered path — switch to the **Scrapling MCP server** (server name
`ScraplingServer`; its tools appear as `mcp__scraplingserver_*`), which drives
Chromium via Playwright/Patchright and can both solve anti-bot challenges and fully
render JS before extraction.

## When to reach for this
- `read <url>` returns a Cloudflare interstitial, "Just a moment...", 403, or 503 instead of real content.
- `browser` `tab.goto`/`tab.observe` shows a Turnstile checkbox/challenge that doesn't clear on its own.
- A site is known to sit behind Cloudflare (many docs sites, e-commerce, forums).
- `read <url>` returns only boilerplate — a redirect stub ("Moved to ..."), an empty `<div id="root">`/`<div id="app">` shell, a bare loading spinner, or page metadata with no body text — because the site is a JS SPA that needs a real browser to render.

## Tool selection (cheapest first)
1. `make_request` — plain HTTP, any method (GET/POST/PUT/DELETE via `method`), with
   browser-fingerprinted TLS/headers. Fast, no browser launch. No JS execution — skip
   straight past this for a known SPA or known-protected site.
2. `fetch` — real Chromium (Playwright) for JS-rendered pages without heavy bot
   protection. **This is the fix for JS-SPA content**: pages that come back as an
   empty shell or redirect stub need JS execution before extraction. Pass
   `network_idle: true` for SPAs.
3. `stealthy_fetch` — Patchright (anti-detect Chromium). Use for Cloudflare
   Turnstile/Interstitial, passing `solve_cloudflare: true`. Also covers JS-SPA
   rendering when the site additionally sits behind bot protection.
4. `bulk_get` / `bulk_fetch` / `bulk_stealthy_fetch` — same tools with
   `urls: [...]`, fetched in parallel; use for several pages from one site instead
   of looping single calls.

For multiple pages from the same protected/SPA site: `open_session` with
`session_type: "dynamic"` or `"stealthy"` (browser-level options only: `headless`,
`proxy`, `cdp_url`, `locale`, `useragent`, …), then `session_fetch` per URL —
per-request options (`wait`, `timeout`, `network_idle`, `wait_selector`,
`solve_cloudflare` — stealthy sessions only) go on each `session_fetch` call, NOT on
`open_session` — then always `close_session`. `list_sessions` shows what's open.
One-shot tools never take a `session_id`.

## Notes
- `main_content_only` defaults to true and strips hidden/prompt-injection content
  (display:none, aria-hidden, zero-width chars, HTML comments, template tags) —
  leave it on unless raw markup is specifically needed. `extraction_type`:
  "markdown" (default) / "html" / "text"; `css_selector` narrows content before it
  reaches the model.
- Page known to be behind Cloudflare → go straight to `stealthy_fetch` with
  `solve_cloudflare: true`; don't waste round trips on `make_request`/`fetch` first.
- Page known to be a pure JS SPA with no bot protection → go straight to `fetch`;
  skip `make_request`, and skip `stealthy_fetch`'s challenge-solving overhead.
- Solving Cloudflare can take 30–60 s; the server's MCP timeout is set to 120 s, so
  don't preemptively abort.
- `make_request` follows redirects in "safe" mode by default (rejects redirects to
  internal/private IPs).
- Environment (NixOS): the `ScraplingServer` MCP server is provisioned
  declaratively — `~/.omp/agent/mcp.json` points at the nix `scrapling-runtime`
  package, which pins the Chromium executable and the node driver itself. If
  `mcp__scraplingserver_*` tools aren't in the active tool set, reload MCP
  (`/mcp` → reload) or start a new session. Never run `scrapling install` — the
  package marks dependencies installed, and its apt-based `install-deps` step
  cannot work on NixOS.
