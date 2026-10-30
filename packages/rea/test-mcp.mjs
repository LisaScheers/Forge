import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { createInterface } from "node:readline";

const server = spawn(process.argv[2], ["mcp"], { stdio: ["pipe", "pipe", "inherit"] });
const exited = once(server, "exit");
const lines = createInterface({ input: server.stdout })[Symbol.asyncIterator]();
const timeout = setTimeout(() => server.kill("SIGKILL"), 30_000);

function send(message) {
  server.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", ...message })}\n`);
}

async function response(id) {
  for (;;) {
    const line = await lines.next();
    assert.equal(line.done, false, "MCP server exited before responding");
    const message = JSON.parse(line.value);
    if (message.id === id) {
      assert.equal(message.error, undefined, JSON.stringify(message.error));
      return message.result;
    }
  }
}

try {
  send({ id: 1, method: "initialize", params: {
    protocolVersion: "2025-03-26", capabilities: {},
    clientInfo: { name: "forge-package-check", version: "1" },
  } });
  const initialized = await response(1);
  assert.ok(initialized.serverInfo.version);
  send({ method: "notifications/initialized" });
  send({ id: 2, method: "tools/list", params: {} });
  const { tools } = await response(2);
  assert.ok(tools.some(({ name }) => name === "binary_session"));
  console.log(`MCP initialized and advertised ${tools.length} tools`);
  server.stdin.end();
  const [code] = await exited;
  assert.equal(code, 0);
} finally {
  clearTimeout(timeout);
  if (server.exitCode === null) server.kill("SIGKILL");
}
