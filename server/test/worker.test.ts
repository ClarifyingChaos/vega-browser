// Runs with: node --test server/test/   (Node 23+, which runs TypeScript directly)
import { test } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import worker, { Account, validPath, verifyGoogleIDToken, LIMITS } from "../src/worker.ts";

/** Durable Object state backed by an in-memory SQLite database, with sockets that record what they were sent. */
function fakeState() {
  const db = new DatabaseSync(":memory:");
  const sockets: { sent: string[]; send(t: string): void }[] = [];
  return {
    sockets,
    storage: {
      sql: {
        exec(query: string, ...bindings: unknown[]) {
          const statement = db.prepare(query);
          const rows = /^\s*select/i.test(query) ? statement.all(...(bindings as any[])) : (statement.run(...(bindings as any[])), []);
          return { toArray: () => rows };
        },
      },
    },
    acceptWebSocket(_s: unknown) {},
    getWebSockets() { return sockets; },
    addSocket() { const s = { sent: [] as string[], send(t: string) { this.sent.push(t); } }; sockets.push(s); return s; },
  };
}

function account() {
  const state = fakeState();
  return { state, account: new Account(state as any, {} as any) };
}

const req = (path: string, init?: RequestInit) => new Request(`https://sync.example${path}`, init);

test("paths are limited to Vega's folders and plain names", () => {
  assert.ok(validPath("devices/1602BDFD-5FFB-4E98-8D1D-B5A23FDC3195.enc"));
  assert.ok(validPath("profile.json"));
  for (const bad of ["../etc/passwd", "devices/../x", "devices/a/b", "other/x.enc", "", "devices/" + "a".repeat(300)]) assert.ok(!validPath(bad), bad);
});

test("a file put is listed, read back, and announced to live sockets", async () => {
  const { state, account: a } = account();
  const socket = state.addSocket();
  const body = new Uint8Array([1, 2, 3, 4]);
  const put = await a.fetch(req("/v1/blobs/devices%2FA.enc", { method: "PUT", body }));
  assert.equal(put.status, 200);
  const { stamp, seq } = await put.json() as any;
  assert.equal(seq, 1);
  const list = await (await a.fetch(req("/v1/list?dir=devices"))).json() as any;
  assert.deepEqual(list.files, [{ name: "A.enc", stamp, seq: 1 }]);
  const got = new Uint8Array(await (await a.fetch(req("/v1/blobs/devices%2FA.enc"))).arrayBuffer());
  assert.deepEqual(got, body);
  assert.deepEqual(JSON.parse(socket.sent[0]), { path: "devices/A.enc", stamp, seq: 1 });
  // Writing again bumps the sequence; a missing file is 404.
  await a.fetch(req("/v1/blobs/devices%2FA.enc", { method: "PUT", body: new Uint8Array([9]) }));
  const list2 = await (await a.fetch(req("/v1/list?dir=devices"))).json() as any;
  assert.equal(list2.files[0].seq, 2);
  assert.notEqual(list2.files[0].stamp, stamp);
  assert.equal((await a.fetch(req("/v1/blobs/devices%2FB.enc"))).status, 404);
});

test("limits: size, count and path", async () => {
  const { account: a } = account();
  assert.equal((await a.fetch(req("/v1/blobs/devices%2Fbig.enc", { method: "PUT", body: new Uint8Array(LIMITS.maxBlobBytes + 1) }))).status, 413);
  assert.equal((await a.fetch(req("/v1/blobs/..%2Fescape", { method: "PUT", body: new Uint8Array(1) }))).status, 400);
});

test("each account sees only its own files", async () => {
  const states = new Map<string, Account>();
  const env: any = {
    DEV_TOKEN: "dev-secret", GOOGLE_CLIENT_ID: "x",
    ACCOUNTS: { idFromName: (n: string) => n, get: (id: string) => { if (!states.has(id)) states.set(id, new Account(fakeState() as any, env)); return states.get(id)!; } },
  };
  const auth = { Authorization: "Bearer dev-secret" };
  assert.equal((await worker.fetch(req("/v1/list?dir=devices"), env)).status, 401, "no token");
  assert.equal((await worker.fetch(req("/v1/list?dir=devices", { headers: { Authorization: "Bearer wrong" } }), env)).status, 401, "wrong token");
  await worker.fetch(req("/v1/blobs/devices%2FA.enc", { method: "PUT", body: new Uint8Array([1]), headers: auth }), env);
  const list = await (await worker.fetch(req("/v1/list?dir=devices", { headers: auth }), env)).json() as any;
  assert.equal(list.files.length, 1);
  assert.deepEqual([...states.keys()], ["dev"]);
});

test("Google ID tokens: signature, audience and expiry are checked", async () => {
  const pair = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const jwk = { ...(await crypto.subtle.exportKey("jwk", pair.publicKey)), kid: "k1", alg: "RS256" } as any;
  const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
  async function token(claims: object, kid = "k1") {
    const head = enc({ alg: "RS256", kid }), body = enc(claims);
    const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", pair.privateKey, new TextEncoder().encode(`${head}.${body}`));
    return `${head}.${body}.${Buffer.from(sig).toString("base64url")}`;
  }
  const now = Date.now();
  const good = { iss: "https://accounts.google.com", aud: "client", sub: "123", exp: now / 1000 + 600 };
  assert.deepEqual(await verifyGoogleIDToken(await token(good), "client", now, [jwk]), { sub: "123" });
  assert.equal(await verifyGoogleIDToken(await token({ ...good, aud: "other" }), "client", now, [jwk]), undefined, "audience");
  assert.equal(await verifyGoogleIDToken(await token({ ...good, exp: now / 1000 - 3600 }), "client", now, [jwk]), undefined, "expired");
  assert.equal(await verifyGoogleIDToken(await token({ ...good, iss: "evil.example" }), "client", now, [jwk]), undefined, "issuer");
  const t = await token(good);
  const tampered = t.split(".").map((p, i) => (i === 1 ? enc({ ...good, sub: "999" }) : p)).join(".");
  assert.equal(await verifyGoogleIDToken(tampered, "client", now, [jwk]), undefined, "tampered claims");
  assert.equal(await verifyGoogleIDToken(await token(good, "unknown"), "client", now, [jwk]), undefined, "unknown key");
});
