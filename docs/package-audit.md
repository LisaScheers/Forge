# Package pins and patches — 8 November 2026

This audit covers explicit package-version overrides, immutable source selections,
forked flake inputs, all local `.patch` files, and inline package workarounds.
Ordinary dependency lockfiles and generated local-tool version numbers are not
temporary version holds. Sources remain hash-locked for reproducible builds.
No configuration was activated and no deployed database was opened.

## Updated or removed

| Package or input | Result | Evidence or remaining constraint |
| --- | --- | --- |
| Home Manager | Returned from Lisa's Nushell branch to upstream master | Upstream `modules/programs/nushell.nix` is identical to the fork's module, including session-environment loading. |
| Authentik | Removed the temporary commit pin; updated to 2026.8.5 | [PR #193](https://github.com/nix-community/authentik-nix/pull/193) merged. Current authentik-nix also carries its X-Forwarded-For fix. Its own dependency set remains independent. |
| deploy-rs | Removed the old commit restriction; current master is `1cec0527`, after 1.0.0 | Current upstream retains Darwin activation support. Existing Darwin mode restrictions remain. |
| Helium | Removed the commit restriction; current master packages 0.21.1.1 | Current upstream includes ARM Linux and the Darwin updater/CRLSet distinction. |
| Movie Night | Removed the commit restriction | The selected commit `c2b5613c` is still upstream main, including the CMAF keyframe fix. Future normal input updates can now advance it. |
| Forgejo, Home Assistant, Sonarr | Removed the application migration holds; both application inputs now track Nixpkgs master | Lisa confirmed migration and recovery checks were complete. Current packaged versions: Forgejo LTS 15.0.11, Home Assistant 2026.10.4, Sonarr 4.0.20.3014. PostgreSQL remains on major 18. |
| Aurora Viewer | Advanced to `24fe0e77`, after 0.9.3; removed `browser.patch` and most of `macos.patch` | Browser integration, media-pack selection, texture-page limits, render scaling and masked-pixel rejection are upstream. The remaining blended-alpha optimization and GPU fixtures were rebased. Bundle metadata also advances to 0.9.3. |
| CLIProxyAPIPlus | Both binary and capture packages advance to 8.0.56-0 | Current upstream still drops full-queue log chunks and treats response `text` as a string. Both local fixes remain; capture and interrupt regression tests run in the package. |
| Asterion kernel | Advanced the fork to `8eddf5ae` | Reconstructed Linux 7.2.11 plus immutable fork diff matches upstream Git tree `f6a78458d22f771c89af804c4f82ac4723362c06`. Both local patches still apply. |
| Asterion m1n1 | Advanced to `7f6df965` | Current Aurora integration branch; its existing Cargo dependency hash remains valid. |
| Aurora Mesa | Advanced to `8ac88a26` | Current Aurora branch; the Nix split-Clang-library substitution remains necessary. |
| Asterion firmware extractor | Advanced the extraction recipe to `e93743d5` | This matches the installer override and current Asahi installer main. Firmware bytes and output digest remain fixed. |
| Asterion Zed binary | Advanced to nightly 3504, 1.29.0, `b5cd310b` | Official release-asset API supplied the immutable download URL; installation checks verify version, commit and shared libraries. |
| Zed cargo-about override | Removed | The selected Zed source now clears the absent `cli` feature itself. |
| Firefox / Thunderbird | Removed the ARM LTO overrides | Both derivation IDs now match unmodified Nixpkgs. ARM Firefox 159.0.1 is in cache.nixos.org; the exact Thunderbird 159.0 build is currently absent. The standard Thunderbird wrapper uses that same build. No Mozilla source build was started. |
| PostPlan | Advanced from 0.0.4 to 0.0.6 | Dependency requirements are unchanged, so existing resolved dependencies were retained and the NPM dependency hash refreshed. Authentik and local-storage substitutions remain. |
| Firestorm | Advanced from 7.2.4.80712 to 7.2.5.81788 | Official Linux AVX2 release archive, hash verified. The wrapper now supplies GTK3 instead of deprecated GTK2; the shipped viewer supports loading GTK3. |
| Brotli replacements | Replaced the standalone decoder patch with upstream 1.2.1 | [1.2.1](https://github.com/google/brotli/releases/tag/v1.2.1) includes the decoder and platform fixes. ABI-compatible grafts remain for older package closures and container libraries. |
| PyArrow replacement | Replaced the custom 25.0.1 wheel with upstream 26.0.1; removed its custom Dockerfile | [Arrow 26.0.1](https://github.com/apache/arrow/blob/apache-arrow-26.0.1/cpp/thirdparty/versions.txt) builds Brotli 1.2.1. Container distribution metadata is replaced along with the modules. |
| Cognee API/MCP | Advanced both immutable image digests to the 6 November builds of 1.6.7 | Python 3.12, Pillow library names and MCP hook points checked in isolated containers. API still needs the Arrow overlay; MCP already ships 26.0.1, so its Arrow overlay was removed. |
| Cognee upload-loader and query-proxy workarounds | Removed | 1.6.7's internal loader has no second local-path access gate. The wrapper still bounds Fastembed threads and installs the local email index. The current query proxy provides `select`/`limit`, replacing the private `_add` workaround. |
| hls.js / D3 | Advanced to 1.7.4 / 7.9.2 | Immutable, hash-verified assets; D3's URL now names its exact version. |
| Lix | Checked latest main `27e147a7`; retained `439e63a1` | The candidate passed its unit tests and legacy functional tests, but two functional2 cases failed to connect to their test daemons. The export-test patch still applies and remains necessary; this update was not accepted. |
| `update-ethnum.patch` | Deleted | No recipe references it. |

## Retained for a reason

| Package or workaround | Why it remains |
| --- | --- |
| REA 6.8.0 and its release lockfile | 6.8.0 is the latest published release. The runtime, NativeAOT bridge and dependency lockfile must advance together. |
| REA WABT 1.0.42, sigrok 0.7.2, mitmproxy 12.2.3 | The current runtime's integration contracts require these versions. WABT is also the latest release. Newer mitmproxy 12.3.1 does not meet that contract. |
| REA pwndbg 2026.09.15, Unicorn 2.1.2, pyelftools 0.33, unchanged pwntools 4.15.0 | The core/binary integration explicitly requires these exact versions and unchanged upstream sources. Newer pwndbg 2026.10.28 and Unicorn 2.1.4 cannot simply replace them. |
| REA Kuna 1.833, Wakaru 1.14.0, JADX bridge, NativeAOT and Frida selections | These are the selected REA release's verified tool and ABI set. Independent updates would require changing and validating REA's contracts. |
| REA Ghidra 12.2 compatibility substitution | REA 6.8's release policy still rejects the packaged Ghidra minor without it. |
| Cutter Qt template patch | 2.5.0 remains the latest Cutter release and still uses template names in `.ui` files. The typedef and UI substitutions remain necessary with Qt 6.12. |
| mautrix-discord's eight patches | 0.7.7 remains its latest release. Local relay recovery/features, plural proxying, history/content/reactions, missing thread starters and media-retention behavior are still local. |
| Pluralmatrix's three patches | `d10e51a4` remains upstream main. Client authentication, integration and reaction-control patches have no later source to move to. Prisma and crypto engine selections match that source's dependency lockfiles. |
| Gotify Authentik plugin | `2c167190` remains upstream main. Building the plugin within the server's module preserves Go toolchain/dependency compatibility. |
| Asterion J516s firmware qualification / opaque-X patches | Current kernel still lacks this Mac's measured firmware TEXT digest and its panel alpha-division fix. Both patches apply to the newer kernel source. |
| Apple firmware 14.8.3 | Selected byte ranges, board-specific firmware and a verified output digest form one extraction unit. An arbitrary newer macOS image is not interchangeable. |
| Asahi installer firmware-parser override | Nixpkgs still packages 0.8.0; the override is already at current upstream main and handles newer Wi-Fi firmware names. |
| m1n1 proxy heap / DTB normalizations | Local RAM-payload sizing and J516s admission requirements, rather than old upstream bug fixes. |
| Zed cargo-bundle patch clearing | Zed still uses its 0.6.1 fork, which lacks `tests/common.rs` targeted by Nixpkgs' newer integration-test patch. |
| Nushell Darwin test disabling | 0.116.1 is current upstream; the documented TTY/SHLVL issue is a builder-environment constraint. |
| debugpy Darwin test correction | 1.8.22 is current upstream. The Nix LLDB path substitution still needs the corresponding test expectation. |
| Steam CEF GPU disabling | M3 rendering constraint. This tracks the normal package input; changing package versions does not establish that the hardware constraint is gone. |
| WebCord update-notification change / Darwin rebuild output wrappers | Declarative update and build-output policies, not temporary upstream fixes. |
| Certificate-trust compatibility | Selected nix-darwin still names three roots absent from NSS. Other unknown blacklist names must continue to fail. Explicit root exclusions and Apple's certificate-file filtering are policy. |
| OrbStack 2.2.5 fallback | 2.2.5 remains the latest release; selected base Nixpkgs still has 2.2.4. The override already becomes inactive when Nixpkgs catches up. |
| PostgreSQL major 18 | The configured data directory and migration-completion marker belong to PostgreSQL 18. A later major requires a separate cluster upgrade. |
| .NET 8.0.33 / 10.0.14 replacements | Both are the current maintenance runtime versions. Older pinned application closures still need the replacements. |
| Cognee Ladybug 0.21.0 and matching JSON extension | Current API still ships 0.19.0. 0.21 fixes the known WAL corruption. Newer 0.22.3 exists, but Cognee's migration mapping only covers through storage code 43/0.19.0; advancing the existing graph requires separate storage compatibility and recovery validation. |
| Cognee Pillow Brotli overlays | Both new images still ship the same Brotli 1.2.0 shared libraries under Pillow's hashed filenames. Their replacements remain necessary. |
| Cognee Fastembed and MCP adaptations | Current embedding code still omits the thread argument. OAuth configuration, TLS-origin allowance and email-source enrichment are local integrations. |
| Jellyfin LDAP Authentication 24.0.0.0 | Latest version in the official plugin archive. |
| Comic Code source/version labels | Licensed source assets, not a workaround holding back a public package release. |
| Local tools marked 0.1.0 or 1 | Repository-owned package versions for Chrome Tab, Forgejo API, Discord migration and GPU smoke tools; there is no independent upstream package release to substitute. |

## Verification

Completed checks:

- Native builds: deploy-rs 1.0.0, Helium 0.21.1.1, CLIProxyAPIPlus 8.0.56-0, PostPlan 0.0.6;
  Linux capture-package build and its logging, response and interrupt tests;
  all 10 CLIProxy/ClickHouse integration tests pass.
  PostPlan's patched web/authentication/storage module graph loads with an
  unconnected test database pool.
- Asterion Mesa and Zed Nightly builds; m1n1's 449 passing tests (19 skipped).
  Kernel source reconstruction matches the upstream Git tree.
- Firmware extraction reproduces the independently verified `firmware.cpio` hash.
- Firestorm 7.2.5 Linux FHS package builds with GTK3.
- Brotli decoder, Node 22/24 and .NET 8/10 regression controls pass.
- API image with upstream Arrow overlay and native MCP image both pass Arrow
  malformed-input rejection, Parquet round trips, LanceDB search and Pillow controls.
  Distribution metadata matches the imported Arrow version.
- New API imports the local wrapper with Ladybug 0.21.0; MCP hook points and OAuth
  constructor arguments remain compatible. New query methods expose the same
  builder operations used by the removed workaround.
- Cognee's 37 tests and Watch Room's five tests pass in explicit dependency environments.
- Changed Nix files pass Alejandra; `git diff --check` passes.

The Aurora build passes all 7,920 tests (52 ignored), its isolated HTTP fixture
and the installed version check. The Asterion kernel and both patched GPU/display
modules build successfully; the modules report the matching kernel vermagic.
The builder's installed SSH alias still uses an untrusted user. Locally generated
build inputs were transferred through the already-declared `root@default`
account for verification, without activating configuration or changing VM policy.
The newer Lix candidate failed two functional2 test cases (`test_store_system`
and `test_trivial_assert`) with daemon-socket connection errors; its lock entry
was restored to the previously selected revision.

Repository-wide checks have existing blockers: `nix flake check --no-build
--all-systems` fails on devenv's missing `nix2container` / `mk-shell-bin` inputs;
the dendritic check rejects the vendored `visualize/_package.nix`, reproduced at
baseline commit `d447e12a5f5fff362083161382d7c9ee4094802c`. The full format check
also reports six unchanged files: `gh-dash.nix`, `git.nix`, `codex/default.nix`,
`antigravity.nix`, and Matrix's two backup test modules.

No host configuration was activated. Production database migrations, live Cognee
retrieval and Asterion boot/GPU qualification remain separate deployment checks.
