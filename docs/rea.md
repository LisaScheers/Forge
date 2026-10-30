# REA

`home.rea` installs the pinned REA CLI, registers its local MCP server through
`programs.mcp`, and installs the matching `reverse-engineer-anything` skill for
Codex. Lisa's main Home Manager profile selects it on Vega, Nook, and Asterion.

The package uses REA's published 6.8.0 runtime and skill with the matching
release lockfile. Node 26 supplies a supported runtime independently of the
shell's Node version. Linux also gets the required procps `ps` on REA's PATH.

The default package includes the toolchain and supplies absolute tool paths to
both the CLI and MCP server:

| Tools | Availability |
| --- | --- |
| Ghidra 12.1.4, its pinned REA NativeAOT extension, and JDK 21 | Vega, Nook, Asterion |
| Kuna 1.833, Rizin, Cutter, GNU objdump, LLDB | All three hosts |
| JADX CLI and headless MCP JAR 0.7.1, Apktool, ADB | All three hosts |
| ILSpy CLI | All three hosts |
| WABT 1.0.42 | All three hosts |
| Helium browser | All three hosts |
| Wireshark `tshark` and `capinfos` | All three hosts; some REA capture operations require Linux |
| Frida Node binding 17.23.2 and Frida CLI tools | All three hosts |
| Binwalk 3.1.0, Unblob 26.6.4, mitmdump 12.2.3, sigrok-cli 0.7.2, GDB, prlimit | Linux |
| Python with pwntools 4.15.0, pyelftools 0.33, Unicorn 2.1.2; pwndbg 2026.09.15 | Linux x86-64, matching REA's admitted host profile |
| Wakaru 1.14.0 for JavaScript source recovery | Linux x86-64 |

Ghidra is the default native provider so installing Kuna alongside it does not
make automatic provider selection ambiguous. Select Kuna explicitly when needed.
Kuna uses the exact release verified by REA, including its matching Sleigh specs.
Home Manager installs the matching Cutter bridge in its user plugin directory;
open a target in Cutter to make that GUI session available to REA.

The Frida binding comes from the exact upstream release archive for the host,
with a fixed hash. npm's networked installation hooks remain disabled.
Firmware, packet and signal tools use Nix's absolute `prlimit` path rather than
assuming `/usr/bin/prlimit`. ARM Linux Apktool supports Rea's decode workflow;
its x86-only native APK rebuild helper is omitted.

Build the package without activating the home configuration:

```sh
nix build .#rea
./result/bin/rea --version
```

Apply the Home Manager configuration through the usual host switch, then restart
Codex to load the MCP server and skill. Activation refreshes only REA's entry in
Codex's mutable configuration; unrelated app settings and MCP servers remain.
The Codex entry includes its complete command, arguments, environment and timeouts:
Home Manager replaces an explicitly configured server table as a whole. The sync
helper rejects entries without a command or URL before changing the live file.
MCP launches the pinned REA script directly so REA can verify its identity, with
the bundled tools on its PATH.

Check the installed MCP adapter and the providers configured by this module:

```sh
rea mcp doctor --json
rea doctor --client codex --provider ghidra --provider jadx --provider kuna --json
```

The scoped `healthy` result checks the selected client and providers. The broader
`environment_healthy` result also includes other detected clients, optional engines,
and REA's shared skill location. Home Manager installs the skill under
`~/.codex/skills`; REA's shared-skill check expects regular files under
`~/.agents/skills` and rejects Home Manager's symlinks.

Hopper, IDA and JEB remain separately supplied proprietary alternatives. Nixpkgs'
Hopper package is an older demo outside REA's supported installer workflow.
Device-side Frida servers, connected Android devices, and a running Cutter or
browser session are target resources, not services started by this module.
macOS native runtime operations also use Apple's existing Xcode command-line
tools and macOS permissions. No system configuration is activated by a build.

Override engine settings through the module when needed:

```nix
forge.rea.environment = {
  REA_ANALYSIS_PROVIDER = "kuna";
};
```

`forge.rea.package` overrides the package, and `forge.rea.enable = false` disables
the feature and removes its managed Codex registration on the next activation.
Update the pinned runtime URL/hash, release lockfile URL/hash, and `npmDepsHash`
together in `packages/rea/package.nix`. Tool paths live in `packages/rea/tools.nix`,
with dependency recipes alongside it; pwndbg uses its pinned upstream Nix flake. Use Nix to
update this installation.

Upstream: [REA](https://github.com/morluto/rea),
[installation guide](https://github.com/morluto/rea/blob/rea-agents-6.8.0/docs/installation.md).
