# Vega Sync server

Optional. Vega syncs through iCloud Drive or Google Drive without it. This server makes sync live (a change on one
Mac reaches the others in seconds) and keeps working for people who use neither.

- **What it stores:** the same files Vega writes to iCloud or Drive (`devices/…`, `passwords/…`, `settings/…`,
  `openTabs/…`). They're sealed on the Mac with the sync passphrase, so the server can't read them.
- **Accounts:** Google accounts. Each request carries the Google ID token Vega already gets when you sign in with
  Google; the server checks its signature against Google's keys and keeps files per account (the token's `sub`). No
  passwords or emails are stored.
- **Limits:** 2 MB per file, 500 files and 50 MB per account.
- **Runs on:** Cloudflare Workers with a SQLite-backed Durable Object per account. The free plan covers it
  (100,000 requests a day, 5 GB).
- **No Apple Developer ID needed:** the Mac talks to it over HTTPS and WebSocket like any website.

## Deploy (needs your Cloudflare account)

1. `npx wrangler login`
2. In `wrangler.toml`, set `GOOGLE_CLIENT_ID` to the client ID in Vega's Google sign-in configuration.
3. `npx wrangler deploy` → it prints the address, e.g. `https://vega-sync.<you>.workers.dev`.
4. On each Mac: `defaults write com.vega.browser fork.sync.serverURL https://vega-sync.<you>.workers.dev/`, then
   Settings › General › Sync › Sync through: **Vega Sync server**, signed in with Google.

## Develop

- Tests: `node --test server/test/` (Node 23+ runs the TypeScript directly).
- Local server: `DEV_TOKEN=secret node server/dev.ts 8787` (memory only, no live WebSocket).
  `ServerStoreCheck` runs Vega's Swift client against it.
