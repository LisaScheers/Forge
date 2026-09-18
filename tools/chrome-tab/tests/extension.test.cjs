const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

function setup() {
  const events = {};
  const commands = [];
  const attached = new Set();
  let result = { result: { type: "number", value: 42 } };
  let reply;
  const listener = (name) => ({ addListener(fn) { events[name] = fn; } });
  const port = {
    onMessage: listener("message"),
    onDisconnect: listener("disconnect"),
    postMessage(value) { reply = JSON.parse(JSON.stringify(value)); },
  };
  const chrome = {
    action: {
      onClicked: listener("click"),
      async setBadgeText() {},
      async setTitle() {},
    },
    runtime: { connectNative: () => port },
    debugger: {
      onDetach: listener("detach"),
      async attach({ tabId }) { attached.add(tabId); },
      async detach({ tabId }) { attached.delete(tabId); events.detach({ tabId }); },
      async getTargets() {
        return [1, 2].map((tabId) => ({ tabId, title: "Example", url: "https://example.test/" }));
      },
      async sendCommand(target, method, params) {
        commands.push({ target, method, params });
        return method === "Runtime.evaluate" ? result : {};
      },
    },
  };
  vm.runInNewContext(readFileSync(join(__dirname, "../extension/background.js"), "utf8"), {
    chrome, TextEncoder, console: { error() {} },
  });
  return {
    events, commands, attached,
    setResult(value) { result = value; },
    click: (id = 1, url = "https://example.test/") => events.click({ id, url }),
    async send(message) {
      await events.message({ id: "test", ...message });
      return reply;
    },
  };
}

test("only toolbar-connected tabs are listed or evaluated", async () => {
  const app = setup();
  await app.click();
  assert.deepEqual((await app.send({ method: "tabs" })).result.map((tab) => tab.tabId), [1]);
  assert.match((await app.send({ method: "eval", tabId: 2, expression: "1" })).error, /not connected/);
  assert.equal(app.commands.length, 0);
});

test("evaluation awaits promises in the page and releases remote objects", async () => {
  const app = setup();
  await app.click();
  assert.equal((await app.send({ method: "eval", tabId: 1, expression: "Promise.resolve(42)" })).result.value, 42);
  assert.equal(app.commands[0].params.awaitPromise, true);
  assert.equal(app.commands[0].params.returnByValue, true);
  assert.equal(app.commands[0].params.timeout, 30000);
  assert.equal(app.commands[1].method, "Runtime.releaseObjectGroup");
});

test("JavaScript exceptions and oversized results are errors", async () => {
  const app = setup();
  await app.click();
  app.setResult({ exceptionDetails: { exception: { description: "Error: deliberate" } } });
  assert.match((await app.send({ method: "eval", tabId: 1, expression: "throw Error()" })).error, /deliberate/);
  app.setResult({ result: { type: "string", value: "x".repeat(900001) } });
  assert.match((await app.send({ method: "eval", tabId: 1, expression: "big" })).error, /900 KB/);
});

test("special values retain their CDP representation", async () => {
  const app = setup();
  await app.click();
  for (const value of [{ type: "undefined" }, { type: "bigint", unserializableValue: "123n" }]) {
    app.setResult({ result: value });
    assert.deepEqual((await app.send({ method: "eval", tabId: 1, expression: "value" })).result, value);
  }
});

test("toolbar, CLI and Chrome detach revoke access", async () => {
  const app = setup();
  for (const detach of [() => app.click(), () => app.send({ method: "detach", tabId: 1 }), () => app.events.detach({ tabId: 1 })]) {
    await app.click();
    await detach();
    assert.match((await app.send({ method: "eval", tabId: 1, expression: "1" })).error, /not connected/);
  }
});

test("native disconnect revokes every connected tab", async () => {
  const app = setup();
  await app.click(1);
  await app.click(2);
  app.events.disconnect();
  assert.equal(app.attached.size, 0);
  assert.match((await app.send({ method: "eval", tabId: 1, expression: "1" })).error, /not connected/);
});

test("restricted URLs cannot be attached", async () => {
  const app = setup();
  await app.click(1, "chrome://settings");
  assert.equal(app.attached.size, 0);
});
