// Local development server: the Worker and its Durable Objects in one Node process, storage in memory.
//   DEV_TOKEN=some-secret node server/dev.ts 8787
// Then point a debug build at it:  defaults write com.vega.browser fork.sync.serverURL http://127.0.0.1:8787/
// (A debug build still signs in with Google; DEV_TOKEN is for scripted checks.) No live WebSocket here.
import { createServer } from "node:http";
import { DatabaseSync } from "node:sqlite";
import worker, { Account } from "./src/worker.ts";

function memoryState() {
  const db = new DatabaseSync(":memory:");
  return {
    storage: { sql: { exec(query: string, ...b: unknown[]) {
      const st = db.prepare(query);
      const rows = /^\s*select/i.test(query) ? st.all(...(b as any[])) : (st.run(...(b as any[])), []);
      return { toArray: () => rows };
    } } },
    acceptWebSocket() {}, getWebSockets() { return []; },
  };
}

const accounts = new Map<string, Account>();
const env: any = {
  DEV_TOKEN: process.env.DEV_TOKEN ?? "", GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID ?? "",
  ACCOUNTS: { idFromName: (n: string) => n, get: (id: string) => { if (!accounts.has(id)) accounts.set(id, new Account(memoryState() as any, env)); return accounts.get(id)!; } },
};

const port = Number(process.argv[2] ?? 8787);
createServer(async (req, res) => {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  const body = chunks.length ? Buffer.concat(chunks) : undefined;
  const request = new Request(`http://127.0.0.1:${port}${req.url}`, {
    method: req.method, headers: req.headers as any, body: req.method === "GET" || req.method === "HEAD" ? undefined : body,
  });
  const response = await worker.fetch(request, env);
  res.writeHead(response.status, Object.fromEntries(response.headers));
  res.end(Buffer.from(await response.arrayBuffer()));
}).listen(port, "127.0.0.1", () => console.log(`vega-sync dev on http://127.0.0.1:${port}`));
