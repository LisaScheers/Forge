# Nixvim

Nixvim provides an AstroNvim-style editor through the shared `lisa-cli` Home
Manager profile. All plugins, Treesitter parsers, language servers, formatters,
linters, and debug adapters are installed by Nix. No Lazy or Mason downloads.
The editor is a standalone package; its configuration lives in the Nix store.

Try it without activating Home Manager, from the Forge checkout:

```sh
nix run .#nixvim
```

After the normal, separately approved Home Manager/system activation, `nvim`,
`vim`, and `vi` launch it. Existing `EDITOR`/`VISUAL` settings are unchanged.

## Features

- Catppuccin Mocha, dashboard, notifications, indentation guides, keybinding help.
- Neo-tree explorer; Snacks file/text/buffer/history/Git pickers.
- Lualine statusline and symbol winbar, Bufferline tabs, Aerial outline.
- Blink completion, LuaSnip snippets, friendly-snippets, automatic pairs/tags.
- Treesitter highlighting, indentation, folds, function/class text objects.
- LSP: Nix, Rust, Lua, Python, C#/Roslyn, JavaScript/TypeScript, shell, JSON, YAML, HTML,
  CSS, Markdown, TOML. Definitions, references, rename, diagnostics, code actions,
  and inlay hints where supported by the server.
- Conform formatting on save; Oxfmt for supported web/data formats;
  nvim-lint with Oxlint for JS/TS and framework scripts, plus Statix, Ruff,
  ShellCheck. Astro/Svelte formatting retains its existing behavior because
  Oxfmt requires additional project dependencies and opt-in for those formats.
- Gitsigns hunks/blame, Lazygit, split navigation, floating/split terminals.
- DAP UI and inline values; Python/debugpy, C#/Netcoredbg, and Rust/C/C++/CodeLLDB adapters.
  Build native executables with debug information before launching them.
  Other debuggers can be configured declaratively or through project launch.json.
- Resession named sessions and a `last` session saved on exit; restore manually.
- Persistent undo and system clipboard support (requires a working clipboard
  session; headless SSH does not supply one).

This recreates the editor features; it does not import AstroNvim or AstroCommunity
packs. Lualine/Bufferline replace Heirline. Nix replaces the in-editor plugin and
tool installers. Language environments still come from each project's
direnv/devenv shell, including Rust toolchains and Python virtual environments.

## C# and .NET

The shared CLI profile installs the .NET 10 LTS SDK. The standalone editor also
includes it, so `:terminal dotnet build` works before system activation. Projects
targeting other SDK versions should provide those SDKs through their dev shell
and select them with `global.json`.

Roslyn loads `.sln`, `.slnx`, and `.csproj` projects for completion, diagnostics,
navigation, rename, and code actions. CSharpier formats C# on save. Zed uses the
same Nix-managed Roslyn and CSharpier packages through its C# extension.

For debugging, run `dotnet build`, open a C# file, and press `F5`. Select the
project's DLL under `bin/Debug/net10.0/` when prompted. Netcoredbg uses the debug
symbols produced by the normal Debug build. Project `launch.json` configurations
can use adapter type `coreclr`.

## Keys

Leader is **Space**; press it and wait for Which-key help.

| Keys | Action |
| --- | --- |
| `Space e`, `Space o` | Toggle/focus explorer |
| `Space ff`, `Space fw`, `Space fb`, `Space fo` | Files, text, buffers, recent files |
| `Space fh`, `Space fk` | Help, keybindings |
| `Space gg`, `Space gs`, `Space gp`, `Space gl` | Lazygit, status, hunk, blame |
| `Space la`, `Space lr`, `Space lf`, `Space ls` | Code action, rename, format, outline |
| `gd`, `gr`, `gI`, `gy`, `K` | Definition, references, implementation, type, hover |
| `[d`, `]d`, `[g`, `]g`, `[b`, `]b` | Previous/next diagnostic, hunk, buffer |
| `Space db`, `Space dc`, `Space du` | Breakpoint, continue, debug UI |
| `F5`, `F10`, `F11` | Continue, step over, step into |
| `Space tf`, `Space th`, `Space tv` | Floating, horizontal, vertical terminal |
| `Ctrl-\`, `Esc Esc` | Toggle terminal, leave terminal input mode |
| `Space tp`, `Space tn`, `Space tu`, `Space tt` | Python, Node, disk usage, processes |
| `Ctrl-h/j/k/l` | Move between splits |
| `Space Ss`, `Space Sl`, `Space Sd` | Save, load, delete session |
| `af`, `if`, `ac`, `ic` | Around/inside function or class (visual/operator mode) |
| `Space w`, `Space q` | Save, quit |

## Maintenance

- Feature wiring: `modules/development/nixvim.nix`.
- Package entry point: `packages/nixvim/nixvim.pkg.nix`.
- Options, plugins, languages: `packages/nixvim/config.nix`.
- Keybindings and runtime hooks: `packages/nixvim/keymaps.lua`.
- Shared nixd settings for all editors: `packages/nixd/settings.nix`;
  see [nixd](nixd.md) for the common Nixpkgs search path and option providers.
- Keep Nixvim's own tested Nixpkgs pin; it is independent of Forge's system pin.
  Update with `nix flake update nixvim`, then run the targeted check below.
- The pinned debugpy package's Darwin LLDB test expects an unpatched command.
  A local override corrects that expectation while retaining the test suite;
  remove the override when the upstream package fixes it.

```sh
nix build .#checks.aarch64-darwin.nixvim --no-link
```

Use `checks.x86_64-linux.nixvim` on Nook. The check starts Neovim with a temporary
home directory and rejects startup errors and configuration warnings.
