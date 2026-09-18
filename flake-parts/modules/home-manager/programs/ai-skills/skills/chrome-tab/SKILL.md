---
name: chrome-tab
description: Use Forge Tab Bridge and its local chrome-tab CLI to inspect or interact with a connected Chrome tab through JavaScript. Use when the user requests this bridge or JavaScript access to an existing Chrome tab.
---

# Chrome Tab Bridge

Use the `chrome-tab` CLI through the shell. It executes JavaScript in the main
frame's page context, with access to the DOM, page globals and logged-in session.
Connecting a tab enables access; it does not expand the user's authorization for
website actions.

## Connect and select

1. Check `command -v chrome-tab`, then run `chrome-tab tabs`.
2. Select the tab by the returned title and URL. Use its `session` and `tabId`
   in subsequent commands; IDs are temporary and must not be guessed.
3. If no bridge or matching tab is connected, ask the user to click **Forge Tab
   Bridge** in the intended HTTP(S) tab. Its badge should read `ON`. The CLI
   cannot attach a tab by itself.

If the CLI or native host is missing, consult `tools/chrome-tab/README.md` in the
Forge repository for the opt-in Home Manager installation. The package is
`chrome-tab` from that flake, not a nixpkgs package. From the repository root,
`nix run 'path:.#chrome-tab' -- tabs` can run the CLI without installing it, but
the Chrome extension and native-host registration must already be configured.
Do not activate a system configuration merely to make the skill available.

## Evaluate

Replace the example session and tab ID with values from `tabs`:

```sh
chrome-tab --session 456 eval 123 '({title: document.title, url: location.href})'
chrome-tab --session 456 eval 123 - <<'JS'
Array.from(document.querySelectorAll('a[href]'), a => ({
  text: a.textContent.trim(),
  href: a.href
})).slice(0, 30)
JS
```

Use a quoted heredoc for multiline JavaScript to prevent shell interpolation.
The input is a JavaScript expression; wrap statements or asynchronous work in
an immediately invoked function, such as `(async () => { return await work(); })()`.
Promises are awaited. Return small JSON-serializable values, not DOM nodes or
cyclic objects. Requests and responses are limited to 900 KB.

Output is a CDP value descriptor, for example
`{"type":"string","value":"Example"}`. Read `value` for ordinary JSON values;
`undefined`, NaN, infinity and bigints retain their `type` or
`unserializableValue`. Errors go to stderr and produce a nonzero exit status.

Before a page mutation, inspect the relevant DOM and current URL to establish
the target, then execute the authorized action and verify the resulting state.
A connected tab remains accessible across navigation, so recheck its URL when
the page may have changed.

## Failures and disconnects

- Run commands sequentially within a session. A busy error means another
  request is in flight; it does not mean this command was queued.
- Evaluation has a 30-second CDP timeout; the bridge waits 35 seconds. A timeout
  or disconnect does not undo page effects or guarantee asynchronous work has
  stopped. Inspect the state before deciding whether a mutation can be retried.
- If Chrome detaches the tab, rediscover it with `tabs` and have the user
  reconnect if needed. A `!` badge's hover text describes connection errors.
- `chrome-tab --session 456 detach 123` revokes access. The user can also click
  the extension again, close the tab or dismiss Chrome's debugging banner.
- This bridge supports HTTP(S) main frames on macOS and Linux. It does not
  target cross-origin iframes, Chrome internal pages or file URLs.
