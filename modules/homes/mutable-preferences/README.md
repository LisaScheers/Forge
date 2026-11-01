# Writable preferences

Use the program's native Home Manager options first. This feature is only
the fallback for programs or files those options do not cover. For example,
the T3 module manages userdata but not its legacy dev profile; Element's
module manages web configuration but not its Electron preferences. Codex's
desktop shortcuts and Antigravity's companion UI also need this fallback.

Each fallback declares its settings as Nix values through
`forge.mutablePreferences`:

```nix
forge.mutablePreferences.".config/example/settings.json" = {
  settings = {
    theme = "dark";
    notifications = true;
  };
};
```

Targets are relative to the home directory. The default format is JSON;
other formats are `yaml`, `lines`, `llsd`, `freecad` and `xml`. Vega imports
this feature; other home profiles can opt in explicitly.

Nix generates the application-format files from these declarations. LLSD
uses native attribute sets, lists and scalar values. FreeCAD groups use
nested attribute sets, with typed leaves such as
`{ type = "uint"; value = 4059297279; }`. Complete XML control layouts declare
a root name and a list of entry attributes. No JSON, XML or CFG snapshots
are needed as source configuration.

JSON objects merge recursively. Lists of objects with `id` fields merge by
identifier, preserving unselected provider token accounts. Other arrays,
including shortcuts, replace the managed bindings. YAML, key/value files,
LLSD settings and FreeCAD groups preserve unselected fields. The `xml`
strategy replaces a complete reviewed layout after checking its root tag.

The importer runs after Home Manager links its files. It rejects malformed
input, symlinks and targets outside the home directory. Changed files remain
writable and private (mode 0600). An unchanged import does not rewrite files.
Tests cover credential preservation, the supported formats, invalid input,
symlink refusal and idempotence.

The reviewed settings imported from Vega on 2026-10-31 omit credentials,
encrypted storage, per-project/account state, window geometry, histories and
device state. Native CLI configuration stays in its CLI module; selected
macOS app defaults stay in the corresponding app module. General macOS
defaults belong to Vega's platform module. Opaque binary preferences remain
local until they have a reviewable export.

VS Code, Antigravity CLI, T3 userdata and Codex use their native mutable
settings options. Docker uses `programs.docker-cli` with the existing
`.docker` directory and macOS credential helper. Its native module makes
`config.json` read-only; `docker login` or `docker context use` cannot rewrite
that file. Registry credentials remain in the keychain, outside Nix.
