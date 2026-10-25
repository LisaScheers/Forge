# Asterion RAM GPU desktop

Asterion (`Mac15,7`, 16-inch M3 Pro, `J516s/T6030/G15S B1`) now runs a
hardware-accelerated Niri and Noctalia desktop in RAM. Native GLES and Vulkan
rendering and compute have passed exact readback tests. Native scanout,
desktop screenshot readback and 200-nit backlight control pass.

The final image passed a fresh tethered boot on 24 October 2026. GPU readiness,
greetd, Niri and Noctalia started automatically. GLES and Vulkan readbacks
passed again in that boot; no manual display or GPU startup was needed.

Physical video testing exposed an additional XRGB scanout fault, now corrected
in `opaque1`: the firmware used the undefined X byte in its alpha division.
Green, blue and cyan disappeared when X was zero, although screenshots and
actual RGB scanout pixels matched exactly. The J516s-only fix disables
`enableGPAlphaDiv` through the qualified 14.7 `A465 {0x43, 0}` request. It checks
the transport and firmware status before starting the display. Lisa confirmed
that all color bars are correct on the physical panel after a fresh boot.

The RAM image itself leaves the installed LUKS root locked and unmounted and
uses the existing Asahi ESP read-only for peripheral firmware. Installation
requires separate explicit mount/install steps. Lisa authorized replacing the
installed Linux generation after physical GPU and video qualification; see the
[installation guide](asterion.md). RAM home files, settings and logs disappear
on reboot unless copied to Vega.

## Components and admission

| Component | Pinned source or local integration |
| --- | --- |
| Kernel | `omacom/linux-aurora` `b6f070c911934c9c377c4be939b883bf32f37acf` |
| Kernel patch/version | `t6030-static-pmp-v1`; `7.2.11-asterion-gpu-test-pmp1` |
| Updated modules | `g15-qualified1-panel-nits1-opaque1`, built against that exact `kernel.dev` |
| Mesa | `aurora-silicon/mesa` `d859e435edc44bf6732b72686867bff8c7f4c002` |
| m1n1 | `omacom/m1n1` `f5a82fdb6264edd2fb0c02e2d0f750bf33380854` |
| Desktop | Niri 26.04; Noctalia 5.3.0, its native C++ implementation |

The kernel source is reconstructed from hashed Linux 7.2.11 and an immutable
fork diff, with base Git tree
`bcd567a2469cdd00bc2f88340f16f70412c8e68e` checked before local patches.
An archive preserves case-distinct Linux paths while passing through macOS.

The static PMP topology is reused with this Mac's bootloader values.
Four UAT reservation names are normalized to the exact unsuffixed paths
expected by G15 admission. Ranges, ownership and firmware checks remain active.
The final module tree must select `asahi.ko` and `appledrm.ko` from `updates/`.

The qualified J516s GFX TEXT identity is:

```text
UUID dbf37c40-ead5-3760-9441-995018782955
TEXT 0x5c000  DATA 0x114000  GKTS marker 0x58e88
SHA256 cd05af6a828b52e4c2fed20086d3d18a7db42e03a8fd6f8354f9f06e0a61363e
```

Two independent September captures and a fresh October capture establish this
image. Only the existing eight GKTS entropy bytes are zeroed before hashing.
Reverse engineering confirms the expected `0xc0`-byte InitData root, magic
`0x0c08e21e83800490` and ENABLE at `+0x2c`. The full-digest entry is scoped to
J516s; no firmware identity override is used. A different identity must stop
for investigation.

Native panel control carries the scoped
[PR183 backlight implementation](https://github.com/omacom/linux-aurora/pull/183).
It exposes `apple-panel-bl` in nits, bounded to 0–500. The desktop readiness
service requires an actual 200-nit readback before starting the GPU and greetd.

## Build and private artifacts on Vega

Build from the Forge checkout on Vega, using this persistent layout outside
the repository:

| Path under `/Users/lisa/.local/state/asterion-gpu/` | Purpose |
| --- | --- |
| `payload-public` | Nix output link and GC root for the public payload |
| `desktop/` | Private desktop payload with Wi-Fi and SSH public key |
| `recovery/` | Private inherited-framebuffer console fallback |
| `installer-public` | GC root for the shared GPU/audio RAM installer |
| `installer-ready/` | Private GPU/audio installer with existing Wi-Fi and file-key access |
| `test-ssh`, `test-ssh.pub` | Dedicated file-based SSH identity |

Keep private directories mode 0700 and private payload/key files mode 0600.
The private image contains a Wi-Fi credential equivalent to the password.
Neither credentials nor the private SSH key belong in Git or the Nix store.

```sh
asterion_state=/Users/lisa/.local/state/asterion-gpu
install -d -m700 "$asterion_state"
nix build path:.#packages.aarch64-linux.asterion-gpu-test \
  --builders 'ssh-ng://orbstack-builder aarch64-linux - 4 1 big-parallel' \
  -o "$asterion_state/payload-public" -L
nix develop path:.#asahi-gpu-tether
```

Open a fresh development shell after updating the payload. The desktop image
uses a 3 GiB proxy heap; an old open 2 GiB shell can be too small. Build checks
cover the heap budget, compiled DTB links, selected modules, gzip integrity
and embedded init. The loader also rejects a payload exceeding its live heap.

Create a key only if one has not already been prepared, then create a new
private payload directory. The helper prompts for Wi-Fi without echoing it:

```sh
test -f "$asterion_state/test-ssh" || \
  ssh-keygen -t ed25519 -N '' -C asterion-gpu-test \
    -f "$asterion_state/test-ssh"
python3 -B scripts/asterion-private-wifi.py \
  "$asterion_state/payload-public" "$asterion_state/desktop" \
  --ssh-public-key "$asterion_state/test-ssh.pub"
python3 -B scripts/asterion-tether-boot.py "$asterion_state/desktop" --check
```

The helper refuses an existing output directory. Preserve a working private
payload while preparing a replacement. NetworkManager and IWD profiles for
`Lisa IOT`, plus the supplied SSH public key, are installed into the RAM root
by initrd services. The private key remains on Vega.

## Tethered boot

Use the existing [proxy setup](asterion.md#install-without-a-usb-drive-tethered-boot);
do not repeat recovery or boot-policy changes. Keep the lid open, connect
power and attach the USB-C data cable. Confirm current serial paths.

In one fresh `asahi-gpu-tether` shell, catch the secondary interface:

```sh
M1N1DEVICE=/dev/cu.usbmodemLD6WQ5P9343 \
  bash "$M1N1_SOURCE/proxyclient/tools/picocom-sec.sh"
```

Start Asterion into its existing Asahi installation. In a second interactive
terminal, open the matching shell and chainload:

```sh
nix develop path:.#asahi-gpu-tether
asterion_payload=/Users/lisa/.local/state/asterion-gpu/desktop
export M1N1DEVICE=/dev/cu.usbmodemLD6WQ5P9341
python3 -B scripts/asterion-tether-boot.py "$asterion_payload" --check
python3 -B "$M1N1_SOURCE/proxyclient/tools/chainload.py" \
  -r "$asterion_payload/m1n1.bin"
```

After `Proxy is alive again`:

```sh
python3 -B scripts/asterion-tether-boot.py "$asterion_payload" \
  --device "$M1N1DEVICE" --esp-uuid 6b247b53-374b-4729-ba44-9b93de5aba90
```

These interfaces and ESP UUID were verified on this Asterion. Recheck the UUID
if its installation changes. Use plain `chainload.py -r`, preserving inherited
display state and boot blobs; do not add `-x` or framebuffer-disabling flags.
The loader requires a PTY and sets the ASCII GPU/DCP chosen properties before
firmware handoff. Stop the secondary listener once Linux takes over.

## Desktop and SSH

The image configures `asterion-gpu-ready` before greetd: check J516s, wait for
the native panel, require 200 nits, load Asahi and wait for `renderD128`.
Greetd starts `asterion-gpu-session` as `nixos` (UID 1000) through PAM/logind.
The fresh boot verified an active local Wayland session on seat0/tty1.

Niri renders on `/dev/dri/renderD128` and presents through the separate native
display card. The internal mode is 3456×2160 at 120 Hz, scale 2; the physical
panel is 3456×2234 with 74 notch rows hidden. Noctalia provides the black/white
bar, launcher, control centre and settings; Foot is the terminal and Fuzzel
is the fallback launcher.

| Shortcut | Action |
| --- | --- |
| Mod+Return | Terminal |
| Mod+D or Mod+Space | Noctalia launcher |
| Mod+S | Control centre |
| Mod+Comma | Settings |
| Mod+Shift+D | Fuzzel fallback |
| Mod+Shift+Q | Close window |
| Mod+Shift+S | Screenshot |

For SSH, use the file key with the agent disabled. Choose a fresh host-key file
for each RAM boot and reuse it for subsequent connections within that boot:

```sh
ssh -i "$asterion_state/test-ssh" -o IdentityAgent=none \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$asterion_state/known-hosts-opaque1" \
  root@asterion-gpu-test
```

The observed address is `192.168.107.7`. Host keys regenerate on RAM boot.
Password SSH login is disabled. The m1n1 cable supplies no network connection.

## Checks, recovery and limits

Run `sudo asterion-gpu-check --run` in the RAM system for bounded GLES and
Vulkan tests. It first checks J516s, the boot marker, tmpfs root and absence of
writable block-device mounts. Results and kernel logs go under
`/run/asterion-gpu-test.*`; copy them to Vega before rebooting.

Verified in the running hardware session on 24 October 2026:

- GLES 3.2 and Vulkan 1.4.363 identify Apple M3 Pro / G15S B1.
- Each API passes six exact triangle pixel readbacks and 32 compute integer
  readbacks. Twenty cycles of both tests pass: 40 API test runs.
- A real Wayland `vkcube` renders through Niri using the native GPU, with
  screenshot readback. Niri, Noctalia's bar, launcher and settings are visible.
- Panel levels 100, 300 and 200 nits pass actual-brightness readback; the
  session is left at 200. Noctalia logs the native Apple renderer.
- Source builds, module vermagic/selection checks and payload checks pass.
  Seven offline loader tests and three private-overlay tests pass.
- Fresh final-image boot `b95fd75b-963a-4c4c-84db-d41c9110f276` starts
  `asterion-gpu-ready` and greetd successfully. The correct modules come from
  `updates/`; Niri and Noctalia run as `nixos` on active seat0/tty1. Both native
  API checks pass at `/run/asterion-gpu-test.qHThlm`.
- Another twenty GLES/Vulkan cycles pass on that automatic boot. A bounded
  Wayland Vulkan run completes 120 frames with exit 0. Native DCP reports
  `started=1`, `failed=0`, imported GPU framebuffer 48 and 4,274 completed swaps.
  No systemd units are failed; actual panel brightness remains 200.
- The color-corrected boot `c7e8f354-5f40-4f7b-a433-a1a7838d38a0` reports
  `opaque_x attempted 1 ready 1 status 0x0`, with native display and GPU startup
  successful. GLES and Vulkan exact readbacks pass again. The scanout's raw X
  bytes still equal R (legal for XR24); all six RGB/CMY bars now show correctly
  on the panel, confirmed by Lisa. This tests physical color beyond screenshots.

The public output is
`/nix/store/9mx2xdaq8czx1dmwyvslwdkyc99yqnpz-asterion-gpu-test`.
The private desktop `SHA256SUMS` file hashes to
`51c9d9165461ed56ff153027af18a26d5cc7df1d970f27c963bc24b17888c0f3`.
Saved logs and screenshots are under
`/Users/lisa/.local/state/asterion-gpu/evidence/`; the public output is GC-rooted
at `payload-public`.
The preceding image is preserved under `desktop-before-opaque1/` and
`payload-public-before-opaque1`; the console `recovery/` payload is unchanged.

For a blank screen or failed desktop startup, boot the private `recovery/`
payload through the same tether procedure. Its fallback must disable native
display takeover and desktop/GPU autostart, retain Wi-Fi and file-key SSH,
and reach the inherited framebuffer console. The durable copy is byte-identical
to the previously booted console payload that Lisa physically confirmed, and
passes the loader's complete checksum check. Its `SHA256SUMS` file hashes to
`caf5477c4397e2452fe082fee2abe2564018ccc5611bb2cf80ef34b0c101177d`.

Sleep is disabled. Protected J516 speaker playback was subsequently verified
with the shared audio module: Lisa heard the test tone and `speakersafetyd`
remained healthy. External displays, recording, headphones and suspend/resume
remain unqualified. A GPU fail-stop requires reboot; preserve logs first and
do not force a refused firmware identity. Stop the USB proxy listener before
a normal installed boot. The installation guide describes the shared boot
image and recovery backups.
