const HOST = "dev.bylisa.chrome_tab";
const connected = new Set();
const toggling = new Set();
let nativePort;

async function badge(tabId, text, title) {
  await chrome.action.setBadgeText({ tabId, text });
  await chrome.action.setTitle({ tabId, title });
}

async function disconnect(tabId) {
  connected.delete(tabId);
  try {
    await chrome.debugger.detach({ tabId });
  } catch {
    // Closing the tab or Chrome's debugging banner can detach first.
  }
  await badge(tabId, "", "Connect this tab to chrome-tab").catch(() => {});
}

async function dispatch(message) {
  if (!message || typeof message.id !== "string") {
    throw new Error("Request id is required");
  }
  if (message.method === "tabs") {
    const targets = await chrome.debugger.getTargets();
    return targets
      .filter((target) => connected.has(target.tabId))
      .map(({ tabId, title, url }) => ({ tabId, title, url }));
  }
  const { tabId } = message;
  if (!Number.isSafeInteger(tabId) || !connected.has(tabId)) {
    throw new Error("Tab is not connected. Click the extension in that tab first.");
  }
  if (message.method === "detach") {
    await disconnect(tabId);
    return { detached: true };
  }
  if (message.method !== "eval" || typeof message.expression !== "string") {
    throw new Error("Expected an eval request with a JavaScript expression");
  }
  const response = await chrome.debugger.sendCommand({ tabId }, "Runtime.evaluate", {
    expression: message.expression,
    awaitPromise: true,
    returnByValue: true,
    timeout: 30000,
    objectGroup: "chrome-tab",
  });
  try {
    if (response.exceptionDetails) {
      throw new Error(
        response.exceptionDetails.exception?.description || response.exceptionDetails.text,
      );
    }
    // Preserve undefined, NaN, Infinity and bigint without pretending they are JSON null.
    const { type, subtype, value, unserializableValue, description } = response.result;
    return { type, subtype, value, unserializableValue, description };
  } finally {
    await chrome.debugger.sendCommand({ tabId }, "Runtime.releaseObjectGroup", {
      objectGroup: "chrome-tab",
    }).catch(() => {});
  }
}

function connectHost() {
  if (nativePort) return nativePort;
  const port = chrome.runtime.connectNative(HOST);
  nativePort = port;
  port.onMessage.addListener(async (message) => {
    let reply;
    try {
      reply = { id: message?.id, result: await dispatch(message) };
      if (new TextEncoder().encode(JSON.stringify(reply)).length > 900000) {
        throw new Error("Result exceeds 900 KB; return a smaller value");
      }
    } catch (error) {
      reply = { id: message?.id, error: String(error.message || error).slice(0, 4000) };
    }
    try {
      port.postMessage(reply);
    } catch {
      // The native host may have exited while the JavaScript was running.
    }
  });
  port.onDisconnect.addListener(() => {
    const reason = chrome.runtime.lastError?.message || "Native host disconnected";
    console.error(reason);
    if (nativePort === port) nativePort = undefined;
    for (const tabId of connected) void disconnect(tabId);
  });
  return port;
}

chrome.action.onClicked.addListener(async (tab) => {
  const tabId = tab.id;
  if (!Number.isSafeInteger(tabId) || toggling.has(tabId)) return;
  toggling.add(tabId);
  try {
    if (connected.has(tabId)) {
      await disconnect(tabId);
      return;
    }
    if (!/^https?:\/\//.test(tab.url || "")) {
      throw new Error("Only HTTP and HTTPS tabs can be connected");
    }
    const port = connectHost();
    await chrome.debugger.attach({ tabId }, "1.3");
    connected.add(tabId);
    if (nativePort !== port) throw new Error("Native host disconnected; check its installation");
    await badge(tabId, "ON", "Disconnect this tab from chrome-tab");
  } catch (error) {
    await disconnect(tabId);
    await badge(tabId, "!", String(error.message || error)).catch(() => {});
    console.error(error);
  } finally {
    toggling.delete(tabId);
  }
});

chrome.debugger.onDetach.addListener(({ tabId }) => {
  connected.delete(tabId);
  void badge(tabId, "", "Connect this tab to chrome-tab").catch(() => {});
});
