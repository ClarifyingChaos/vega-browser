// Licensed under GPL-3.0. See LICENSE.
//
// Vega Sync server: a Cloudflare Worker with one Durable Object per account. It stores the same files Vega keeps in
// iCloud Drive or Google Drive ("devices/<id>.enc", "passwords/<id>.enc", ...), already sealed on the Mac with the
// sync passphrase, so the server holds nothing it can read. A WebSocket tells each Mac when another one wrote, so a
// change arrives in seconds instead of at the next timed check.
//
// Accounts are Google accounts: each request carries a Google ID token, checked against Google's keys; the account is
// the token's "sub". No passwords, no email kept.

export interface Env {
  ACCOUNTS: DurableObjectNamespace;
  /** The OAuth client ID Vega signs in with: tokens for any other app are refused. */
  GOOGLE_CLIENT_ID: string;
  /** Local development only: a fixed bearer token accepted as account "dev". Never set in production. */
  DEV_TOKEN?: string;
}

export const LIMITS = { maxBlobBytes: 2_000_000, maxBlobs: 500, maxPathLength: 200 };

/** Paths look like "devices/<uuid>.enc": a known folder, then a plain file name. */
export function validPath(path: string): boolean {
  if (path.length === 0 || path.length > LIMITS.maxPathLength) return false;
  return /^(devices|passwords|settings|openTabs|removed|meta)\/[A-Za-z0-9._-]+$/.test(path) || /^[A-Za-z0-9._-]+\.(json|enc|plist)$/.test(path);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/health") return json({ ok: true });
    if (!url.pathname.startsWith("/v1/")) return new Response("Not found", { status: 404 });
    const account = await authenticate(request, env);
    if (!account) return json({ error: "sign in again" }, 401);
    const stub = env.ACCOUNTS.get(env.ACCOUNTS.idFromName(account));
    return stub.fetch(request);
  },
};

// MARK: - Auth

type JWK = { kid: string; n: string; e: string; alg: string; kty: string };
let googleKeys: { keys: JWK[]; until: number } | undefined;

async function authenticate(request: Request, env: Env): Promise<string | undefined> {
  const header = request.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : new URL(request.url).searchParams.get("token") ?? "";
  if (!token) return undefined;
  if (env.DEV_TOKEN && token === env.DEV_TOKEN) return "dev";
  const claims = await verifyGoogleIDToken(token, env.GOOGLE_CLIENT_ID);
  return claims ? `google:${claims.sub}` : undefined;
}

function b64urlDecode(s: string): Uint8Array {
  const b = atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}

export async function verifyGoogleIDToken(token: string, clientID: string, now = Date.now(),
                                          keys?: JWK[]): Promise<{ sub: string } | undefined> {
  const parts = token.split(".");
  if (parts.length !== 3) return undefined;
  let head: any, claims: any;
  try {
    head = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  } catch { return undefined; }
  if (head.alg !== "RS256") return undefined;
  if (!["accounts.google.com", "https://accounts.google.com"].includes(claims.iss)) return undefined;
  if (claims.aud !== clientID || typeof claims.sub !== "string") return undefined;
  if (typeof claims.exp !== "number" || claims.exp * 1000 < now - 60_000) return undefined;
  const jwks = keys ?? (await googleJWKS());
  const jwk = jwks.find((k) => k.kid === head.kid);
  if (!jwk) return undefined;
  const key = await crypto.subtle.importKey("jwk", jwk as JsonWebKey, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlDecode(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  return ok ? { sub: claims.sub } : undefined;
}

async function googleJWKS(): Promise<JWK[]> {
  if (googleKeys && googleKeys.until > Date.now()) return googleKeys.keys;
  const response = await fetch("https://www.googleapis.com/oauth2/v3/certs");
  const body = (await response.json()) as { keys: JWK[] };
  googleKeys = { keys: body.keys, until: Date.now() + 60 * 60 * 1000 };
  return body.keys;
}

// MARK: - One account's files

/** Minimal shape of the Durable Object storage this file uses, so tests can supply their own. */
export interface SQLStorage {
  exec(query: string, ...bindings: unknown[]): { toArray(): any[] };
}

export class Account {
  private sql: SQLStorage;
  private state: DurableObjectState;

  constructor(state: DurableObjectState, _env: Env) {
    this.state = state;
    this.sql = state.storage.sql as unknown as SQLStorage;
    this.sql.exec("CREATE TABLE IF NOT EXISTS blobs (path TEXT PRIMARY KEY, data BLOB NOT NULL, stamp TEXT NOT NULL, seq INTEGER NOT NULL)");
    this.sql.exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)");
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/live") return this.live(request);
    if (url.pathname === "/v1/list") return this.list(url.searchParams.get("dir") ?? "");
    if (url.pathname.startsWith("/v1/blobs/")) {
      const path = decodeURIComponent(url.pathname.slice("/v1/blobs/".length));
      if (!validPath(path)) return json({ error: "bad path" }, 400);
      if (request.method === "GET") return this.get(path, request.headers.get("If-None-Match"));
      if (request.method === "PUT") return this.put(path, request);
      if (request.method === "DELETE") return this.remove(path);
    }
    return new Response("Not found", { status: 404 });
  }

  private nextSeq(): number {
    const row = this.sql.exec("SELECT value FROM meta WHERE key = 'seq'").toArray()[0];
    const next = (row?.value ?? 0) + 1;
    this.sql.exec("INSERT INTO meta (key, value) VALUES ('seq', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", next);
    return next;
  }

  private list(dir: string): Response {
    const prefix = dir ? `${dir}/` : "";
    const rows = this.sql.exec("SELECT path, stamp, seq FROM blobs").toArray()
      .filter((r) => r.path.startsWith(prefix) && !r.path.slice(prefix.length).includes("/"));
    return json({ files: rows.map((r) => ({ name: r.path.slice(prefix.length), stamp: r.stamp, seq: r.seq })) });
  }

  private get(path: string, ifNoneMatch: string | null): Response {
    const row = this.sql.exec("SELECT data, stamp FROM blobs WHERE path = ?", path).toArray()[0];
    if (!row) return new Response("Not found", { status: 404 });
    // The Mac already has this version: nothing to download.
    if (ifNoneMatch === `"${row.stamp}"`) return new Response(null, { status: 304, headers: { ETag: `"${row.stamp}"` } });
    return new Response(row.data as ArrayBuffer, { headers: { "Content-Type": "application/octet-stream", ETag: `"${row.stamp}"` } });
  }

  private async put(path: string, request: Request): Promise<Response> {
    const data = new Uint8Array(await request.arrayBuffer());
    if (data.byteLength > LIMITS.maxBlobBytes) return json({ error: "too large" }, 413);
    const exists = this.sql.exec("SELECT 1 FROM blobs WHERE path = ?", path).toArray().length > 0;
    const count = this.sql.exec("SELECT COUNT(*) AS n FROM blobs").toArray()[0]?.n ?? 0;
    if (!exists && count >= LIMITS.maxBlobs) return json({ error: "too many files" }, 507);
    const stamp = await sha256Hex(data);
    const seq = this.nextSeq();
    this.sql.exec("INSERT INTO blobs (path, data, stamp, seq) VALUES (?, ?, ?, ?) ON CONFLICT(path) DO UPDATE SET data = excluded.data, stamp = excluded.stamp, seq = excluded.seq",
      path, data, stamp, seq);
    this.broadcast({ path, stamp, seq });
    return json({ stamp, seq });
  }

  private remove(path: string): Response {
    this.sql.exec("DELETE FROM blobs WHERE path = ?", path);
    this.broadcast({ path, stamp: null, seq: this.nextSeq() });
    return json({ ok: true });
  }

  // Live updates: each Mac keeps a WebSocket open; hibernation keeps an idle one free.
  private live(request: Request): Response {
    if (request.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
    const pair = new WebSocketPair();
    this.state.acceptWebSocket(pair[1]);
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  private broadcast(message: unknown) {
    const text = JSON.stringify(message);
    for (const socket of this.state.getWebSockets()) {
      try { socket.send(text); } catch { /* closed meanwhile */ }
    }
  }

  webSocketMessage(socket: WebSocket, message: string | ArrayBuffer) {
    if (message === "ping") socket.send("pong");
  }
}

async function sha256Hex(data: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
