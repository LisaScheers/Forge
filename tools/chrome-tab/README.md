# Forge Tab Bridge

A Chrome Manifest V3 extension and local `chrome-tab` CLI. Click the extension
in an HTTP(S) tab to connect it. The badge reads `ON`, and Chrome displays its
debugging banner. Click again, close the tab, dismiss the banner, or run
`chrome-tab detach TAB_ID` to disconnect.

## Install with Home Manager

Build the package without activating a system:

```sh
nix build 'path:.#chrome-tab'
```

Vega's Home Manager configuration enables the bridge. For another host, import
`config.forge.modules.homeManager.chrome-tab` in its Home Manager composition
and configure:

   ```nix
   forge.chrome-tab.enable = true;
   ```

1. Apply the configuration through your normal approved deployment workflow.
   It installs the CLI, the extension files and Chrome's native messaging manifest.
2. In `chrome://extensions`, enable Developer mode and choose **Load unpacked**.
   Select `~/.local/share/chrome-tab/extension` (expand `~` in the file picker).
3. Click the extension in a normal web tab and run `chrome-tab tabs`.

The manifest includes a public key that fixes the extension ID to
`fjgenihlcmobdjmfnmnhmglpemfkklle`, independent of its load path. Home Manager
allows that ID by default. No private key is distributed or required for loading
the unpacked extension. Reload the extension in Chrome after updating its files.
If you previously loaded the version without a public key, remove that entry
and load the updated extension. A custom build using a different key must also
override `forge.chrome-tab.extensionId` to match.

## Use

```sh
chrome-tab tabs
chrome-tab eval 123 'document.title'
chrome-tab eval 123 '({url: location.href, heading: document.querySelector("h1")?.textContent})'
chrome-tab eval 123 'document.querySelector("button").click()'
chrome-tab eval 123 - <<'JS'
(async () => {
  const response = await fetch('/api/status');
  return response.json();
})()
JS
chrome-tab detach 123
```

Commands print JSON and exit nonzero on errors. Evaluations return the CDP
value descriptor, for example `{"type":"string","value":"Example"}`.
`undefined`, bigints, NaN and infinity retain their type or `unserializableValue`.
Return JSON-serializable data rather than DOM nodes or cyclic objects.

With several Chrome profiles connected, `tabs` includes a `session` identifier.
Use `chrome-tab --session SESSION eval TAB_ID 'document.title'` to select one.
Tab IDs and session IDs are temporary; discover them again after restarting Chrome.

## Behavior and boundaries

- JavaScript executes in the main frame's page context with access to the DOM,
  page globals and the page's logged-in session. Promises are awaited.
- The extension only accepts evaluations for tabs connected with its toolbar
  button. A connected tab stays connected across navigation until detached.
- The local bridge uses Chrome native messaging and a Unix socket in a directory
  owned by the current user with mode `0700`. There is no TCP listener, webpage
  message handler, or remote service. Other processes running as this OS user
  can access connected tabs through the socket.
- Native-host disconnects revoke connected tabs. Click again to reconnect after
  fixing the host installation. Hover over a `!` badge for the error message.
- Evaluations have a 30-second CDP timeout and the bridge waits 35 seconds.
  A timeout is not a rollback: page effects may already have happened, and
  asynchronous page work can continue. Do not automatically retry mutations.
- Requests and results are limited to 900 KB. Chrome internal pages, file URLs,
  cross-origin iframe targeting and Windows are outside this initial scope.
  Chrome may reject protected pages or detach when DevTools is opened.
- Each browser session accepts one CLI request at a time. Concurrent commands
  fail with a busy error rather than queuing page mutations.

Implementation follows Chrome's [debugger API](https://developer.chrome.com/docs/extensions/reference/api/debugger)
and [native messaging protocol](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).

## Checks

```sh
nix shell nixpkgs#python3 nixpkgs#nodejs -c sh -c '
  python3 -B -m unittest discover -s tools/chrome-tab/tests -p "test_*.py" &&
  node --test tools/chrome-tab/tests/extension.test.cjs
'
```

The tests exercise the real native-host process with framed messages and local
socket clients, and the extension worker against a mocked Chrome API. To check
the installed browser integration, connect a disposable page, evaluate its
title and an awaited promise, change its DOM, then disconnect and verify the
same tab rejects further evaluations.
