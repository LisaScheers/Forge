# Asterion

NixOS on the 16-inch M3 Pro MacBook Pro (`Mac15,7`, `J516s`, `T6030`,
`G15S B1`). macOS and Apple recovery remain alongside Linux. This configuration
reuses the existing encrypted Linux root and Asahi ESP.

## GPU, desktop and sound

Hardware qualification on 24 October 2026 established:

- Native GLES 3.2 and Vulkan 1.4.363 render and compute on the M3 Pro.
  Exact pixel and integer readbacks pass, including repeated process starts.
- Niri 26.04 and Noctalia 5.3.0 run on the native eDP display at 120 Hz,
  with 2× scaling and a 200-nit initial backlight.
- The J516s display fix disables firmware alpha division for opaque XRGB.
  Lisa confirmed all RGB/CMY bars and correct video colors on the panel,
  followed by perfect video playback. Screenshots alone missed this fault.
- Built-in speakers play through Asahi's J516 DSP, six-channel speaker route
  and `speakersafetyd` protection. Lisa heard the bounded test tone; the
  protection daemon remained healthy during 48 kHz playback.

The hardware tests above used the tethered RAM system. Installation and normal
boot qualification are recorded separately below; a successful build alone
is not evidence of a successful installed boot.

Generation 2 was installed on 25 October 2026, preserving the existing LUKS2
container, ext4 root, Lisa's home/password, macOS and recovery. The previous
generation remains in systemd-boot. The installed boot image hashes to
`2f7eb9ca1855f268d0dccd0470b17ff1eb6eb4905734cd895fb376f2470c7b8d`;
kernel and initrd copies were checked before reboot. Normal boot
`cdb08d6a-27e9-4eae-84b3-0a4ba4969ccf` mounted the encrypted SSD, started the
native GPU/display and reached password login. Lisa logged into Niri/Noctalia
and confirmed correct colors. GLES and Vulkan exact rendering/compute readbacks
passed as Lisa. Home Manager, the desktop and speaker protection started
without failed units. Lisa heard the three-second protected speaker test at
the upstream default volume (`wpctl 0.7`); the earlier `0.35` test was inaudible.

Sleep, external displays, internal microphone recording and headphone output
have not been qualified. H.264 has a verified hardware decoding path; GPU
rendering and presentation are accelerated. Suspend and hibernation are disabled.
Closing the lid takes no action; shut down before transport.

The installed system and installer share these modules:

| Module | Purpose |
| --- | --- |
| `modules/hardware/apple-silicon/gpu.nix` | Matching kernel, Mesa, replacement modules and desktop readiness |
| `modules/hardware/apple-silicon/gpu-boot.nix` | Qualified m1n1, normalized J516s DTB and U-Boot in the ESP |
| `modules/hardware/apple-silicon/audio.nix` | Upstream Asahi sound, DSP and speaker protection |
| `packages/asterion-gpu-session/` | Validated Niri, Noctalia, terminal and pinned Mesa environment |

The [RAM GPU guide](asterion-gpu-test.md) records exact source pins, firmware
admission, readback tests, private payload preparation and tether recovery.
Firmware identity checks remain enforced. Do not add an identity override to
force an unknown firmware revision through admission.

## Build the system and installer

Use the same Forge revision and `flake.lock` for both. `path:.` includes new
files in an uncommitted checkout; ordinary Git flake references omit untracked
files. These commands build without activating a system:

```sh
nix build path:.#nixosConfigurations.asterion.config.system.build.toplevel \
  -o /tmp/asterion-system -L
nix build path:.#packages.aarch64-linux.asterion-installer \
  -o /tmp/asterion-installer -L
nix build path:.#packages.aarch64-linux.asterion-tethered-installer \
  -o /tmp/asterion-tethered-installer -L
```

An `aarch64-linux` builder is required. Vega uses the existing OrbStack builder
with `big-parallel`. The ISO is under `/tmp/asterion-installer/iso/`. The tethered
output is the qualified RAM GPU image, including install tools and protected
sound. Use **`nix develop path:.#asahi-gpu-tether`** for that image: its matching
fork proxy client reserves a 3 GiB heap. The older `asahi-tether` shell is not
sized for the GPU installer.

The USB ISO relies on a compatible internal m1n1 stage 2 for GPU/DCP firmware
handoff. For an existing stock boot stack, use the tethered procedure to load
the matching fork first. Stop USB proxy listeners before normal installed boot;
a listener deliberately catches early m1n1 and prevents the stored boot chain
from continuing.

The public RAM image contains no Wi-Fi password or private SSH key. Its private
Wi-Fi overlay lives outside the checkout and Nix store. See the RAM guide for
its preparation and permission requirements.

## Install into the existing encrypted root

The existing device layout is specific to this Mac:

| Device identity | Use |
| --- | --- |
| PARTLABEL `asterion-root` | Existing LUKS2 partition |
| Mapper `asterion-root`, ext4 LABEL `asterion` | Linux root and Lisa's home |
| vfat LABEL `ASTERIONEFI` | Asahi ESP |
| ESP PARTUUID `6b247b53-374b-4729-ba44-9b93de5aba90` | Selected boot environment |

Do not format, repartition or recreate this layout. Do not use a whole-disk
installer or disko. Preserve the macOS, iBoot and recovery containers.

From the live system, verify the compatibility and partition identities before
mounting. Unlock locally, keeping the passphrase out of shell history and chat:

```sh
tr '\0' '\n' < /proc/device-tree/compatible
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,LABEL,PARTUUID,MOUNTPOINTS
sudo cryptsetup open /dev/disk/by-partlabel/asterion-root asterion-root
sudo mount /dev/mapper/asterion-root /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=0077 \
  /dev/disk/by-partuuid/6b247b53-374b-4729-ba44-9b93de5aba90 /mnt/boot
```

Back up the partition map, LUKS header, full ESP, existing `/etc/nixos`, and Nix
profiles/database before replacing the generation. Vega's current backups are
under `/Users/lisa/.local/state/asterion-gpu/install-backup/`, mode 0700, with
files mode 0600. Keep these off the laptop.

Copy Forge, including its Git metadata and lock file, to `/mnt/etc/nixos/forge`.
Preserve the previous checkout. Copy working NetworkManager/iwd credentials
as mode-0600 files on the encrypted root; never embed them in Nix expressions.
The dedicated Vega management public key is declarative; its private key stays
on Vega. Generate SSH host keys on the target and record the public fingerprint
before rebooting.

The installed closure is larger than the RAM root. Copy/build directly into the
mounted target store, rather than copying the whole closure into RAM:

```sh
cd /mnt/etc/nixos/forge
sudo nix build path:.#nixosConfigurations.asterion.config.system.build.toplevel \
  --store /mnt --extra-substituters 'auto?trusted=1' \
  -o /mnt/asterion-system -L
sudo env NIX_REMOTE=local nixos-install --root /mnt \
  --system "$(readlink /mnt/asterion-system)" --no-root-passwd --no-channel-copy
```

`NIX_REMOTE=local` lets the pinned Lix installer read the target store inside
the chroot, where its daemon is not running yet.

For a prebuilt closure on Vega, `nix copy` also supports the SSH target store
`ssh-ng://root@ADDRESS?remote-store=/mnt`. Disable the SSH agent and select the
file key explicitly. `nixos-install --system` then uses that target-store path.

Existing Lisa credentials and home are preserved. Check with
`nixos-enter --root /mnt -c 'passwd --status lisa'`: status must be `P`.
Only a fresh installation needs `passwd lisa`; the login password is independent
of the disk passphrase. Root password login stays locked; SSH accepts keys only.

Before reboot, verify the installed kernel/initrd, boot entry and free ESP space.
`m1n1/boot.bin` must contain the qualified fork, normalized J516s DTB, matching
U-Boot and exactly one copy of each GPU/DCP/ESP chosen option. Systemd-boot must
preserve m1n1's populated DTB, rather than loading a fresh disk DTB.

The initrd leaves native GPU/display drivers blacklisted so the firmware console
can show the LUKS prompt. After root mounts, `asterion-gpu-ready` takes over the
display, requires an actual 200-nit readback, loads the GPU and starts greetd.
After creating the panel, it waits for udev and explicitly finishes systemd's
saved-brightness restore before setting 200 nits. Without that synchronization,
the restore could replace 200 with a saved value during the readback check and
prevent the GPU and greeter from starting. A failed brightness check reports
both the requested and actual values in the journal.
Noctalia Greeter uses the matching Mesa environment, the Asterion palette and
2× scaling on `eDP-1`. Idle display blanking is disabled. Lisa and the Asterion
session are preselected; enter the existing login password to start the qualified
Niri/Noctalia session wrapper. Authentication remains required.

The greeter uses the pinned nixpkgs `noctalia-greeter` 1.7.0 module and
AccountsService. Applying a rebuild preserves an active desktop; restart greetd
after saving work, or reboot, to load a changed greeter command.
Generation 3 enabled this greeter on 25 October 2026. Lisa confirmed the graphical
login screen and successful password login back into Niri and Noctalia.

## Desktop and rebuilds

The installed home imports Lisa's full portable profile from Vega: Nushell,
Starship, Codex, Zed's VSCode keymap/theme/extensions, Ghostty, Nerd-patched Comic
Code fonts, Git tooling and development runtimes. Darwin services and credentials
are separate. Helium is the default web browser; 1Password provides the desktop
app, CLI, SSH agent integration, Git signer and browser-native messaging host.
The extension is requested by Chromium policy using Helium's default update URL,
which respects its extension-proxy consent. An explicit Google update URL bypasses
that route and failed to install the extension. Account credentials stay out of Nix.
The custom browser allow-list uses mode `0755` so Nix creates a regular root-owned
file. 1Password's native host rejects the default symlink during its permission
verification, even when the target is read-only.
The 25 October tooling switch opened Helium, 1Password and Zed successfully.
Zed selected the M3 Pro's Vulkan adapter with software emulation disabled.
Lisa completed first-run setup and signed into 1Password locally, then confirmed
the fresh desktop login. The new session exports Helium and the 1Password agent
path, has no forced minimal font configuration, and resolves the Comic Code font.
An authenticated CLI request passed and extension 8.12.42.36 installed successfully.
The SSH agent also passed a signature challenge for the configured Git signing
key. Lisa completed browser enrollment and confirmed that her account is visible
in the extension. After the allow-list permission fix, the native host logged
successful browser verification and connection to the desktop app. Lisa then
confirmed that locking and unlocking the 1Password app also unlocks the extension
without a separate password. Temporary browser diagnostics and their policy were
removed before account enrollment.

On 25 October, the application profile added the official native ARM64
ChatGPT/Codex app, Codex CLI, Discord through WebCord, Thunderbird, a Slack web
app launcher, and a Ghostty launcher for the existing Spotatui Spotify player.
The desktop also includes Papers, Loupe, File Roller and Calculator. Helium
remains the default browser; Thunderbird handles email and calendar links.
Spotify playback through Spotatui requires Spotify Premium. The native Linux
ChatGPT app does not yet provide Computer Use.

Codex's initial model, reasoning effort, fonts, queue and detail preferences
match Vega, with Zed as the editor and `/etc/nixos/forge` trusted. The app keeps
its matching bundled backend; the standalone CLI is managed separately. The
live Codex configuration remains writable, with declarative initial defaults.
Existing preferences were merged once and backed up privately on Asterion.
No Vega account credentials were copied.

Thunderbird's default `lisa` profile contains the primary `scheers` account,
`lisa@scheers.tech`, using the provider's published configuration: IMAP at
`m.scheers.tech:993` and SMTP at `m.scheers.tech:465`, both with implicit TLS.
Passwords are enrolled locally in Thunderbird. Calendar and address-book
collections have not been enrolled; their authenticated discovery is separate
from email setup.

The application generation switched successfully, and ChatGPT with its bundled
app server, WebCord and Thunderbird opened on native Wayland. Thunderbird
reached its password dialog, and Lisa then confirmed successful local sign-in
in all three applications. Codex CLI separately passed its ChatGPT sign-in
check. No email was sent during setup.

Asterion joined the existing Tailscale network as `100.90.119.32`. Codex's
private Cognee endpoint initially resolved to Nook's inaccessible LAN address,
and Asterion's tailnet map did not include Nook (`100.106.233.104`). Lisa approved
and the setup applied this additional shared-tailnet grant:

```json
{
  "src": ["100.90.119.32"],
  "dst": ["100.106.233.104"],
  "ip": ["tcp:443"]
}
```

The existing grants were preserved. An Asterion-only Nix hostname mapping sends
`cognee.local.bylisa.dev` to Nook's Tailscale IP. HTTPS certificate verification
passed through the ordinary hostname, and Codex's OAuth enrollment completed.
A read-only app-server protocol check discovered all four Cognee tools,
including `recall`, without invoking memory tools. The same check confirmed
that the configured `gpt-6.1-sol` model is available to the signed-in account.

Niri follows the bindings/layout in Esmee's `NixOS_config`, adapted to native
Noctalia 5's IPC. Ghostty retains Lisa's Vega terminal preferences. The GPU render
device, software cursor, direct-scanout workaround and 2× native-panel scale are
preserved. Home Manager's config path permits live Niri configuration reloads.

Home Manager owns desktop configuration. The session uses upstream
`niri-session` and the existing PAM/logind user bus. Noctalia supplies the bar,
notifications, launcher and control center. At Lisa's request on 25 October,
Swaylock and Swayidle are disabled, with their shortcuts and session-menu action
removed. Idle locking, idle display blanking and lid-triggered locking are off.

| Shortcut | Action |
| --- | --- |
| Command+Return | Terminal |
| Command+D or Command+Space | Noctalia launcher |
| Command+S | Control center |
| Command+Comma | Settings |
| Command+arrows / Command+Shift+arrows | Focus / move windows and columns |
| Command+PageUp/PageDown | Change workspace |
| Command+Shift+PageUp/PageDown | Move column to adjacent workspace |
| Command+Shift+E | Noctalia session menu |
| Command+1/2/3 | Code/web/chat workspace |
| Command+Q or Command+Shift+Q | Close window |
| Command+Shift+S | Screenshot |
| Media and brightness keys | Protected audio volume and panel brightness |
| Command+brightness keys | Keyboard backlight in 10% steps |
| Command+Shift+K | Keyboard backlight on/off |

From `/etc/nixos/forge`, apply ordinary configuration changes in the current terminal:

```sh
just switch
```

For kernel, GPU driver, Mesa or boot firmware changes, build first and install
the next boot generation:

```sh
sudo nixos-rebuild build --flake path:.#asterion
sudo nixos-rebuild boot --flake path:.#asterion
sudo reboot
```

Kernel, modules, Mesa and boot firmware form a qualified set. Use a reboot for
changes to that set; do not unload the active display/GPU or rebind it live.
The GPU readiness service does not restart during ordinary configuration switches.

## Wi-Fi

Lisa IOT is restricted to 2.4 GHz by the UniFi configuration. The installed
BCM4388 driver detects Lisa Ent and Lisa VPN on 5 GHz channel 40. NetworkManager's
IWD backend reports placeholder frequencies for inactive networks, so use
`iwctl station wlan0 show` to check the actual connected band.

The native Lisa Ent profile uses PEAP/MSCHAPv2 as `uid-lisa@scheers.tech`, requires
protected management frames, and validates `standard.ui.com` against the public
UniFi CA exported from Vega's existing configuration. That CA expires on
24 May 2031; its SHA-256 fingerprint is
`F0:4C:3D:ED:82:71:83:CE:81:E6:BC:D1:9E:40:80:E6:53:29:F2:FD:78:E6:27:B8:04:5F:65:F1:05:98:B6:AB`.
It is trusted only for this Wi-Fi connection. Passwords are agent-owned and
enrolled locally through the desktop's NetworkManager secret agent.

The Nix-generated profile was installed at
`/etc/NetworkManager/system-connections/asterion-lisa-ent.nmconnection`, with a
GC root at `/nix/var/nix/gcroots/asterion-wifi-profile` retaining its public CA.
Its UUID matches the declarative profile in `modules/desktop/asterion/wifi.nix`.
The active Steam generation was preserved during this profile-only update.
NetworkManager accepted the profile and mirrored it into IWD. On 25 October,
Lisa completed local password enrollment. The declared UUID then connected at
5200 MHz (5 GHz channel 40), with a negotiated transmit rate of 648.5 Mb/s.
Certificate validation, the server-name constraint, agent-owned password storage
and required protected management frames remained active. This rate is the
wireless link rate, not an Internet speed test.

UniFi Endpoint's current official Linux package (1.1.7-28) declares `amd64`, and
Ubiquiti offers no ARM Linux build. It was not installed. Lisa Ent's native
802.1X connection does not require that application once credentials are known.

## Steam

The [steam-asahi NixOS module](https://github.com/sm-idk/steam-asahi) installs
**Steam (Asahi)** in the launcher. Run `steam-asahi` from a terminal for logs.
It runs Steam through muvm and FEX, providing the 4 KiB guest pages and x86
translation required on Asterion's 16 KiB ARM system. The ordinary
`programs.steam` module and host 32-bit graphics stay disabled.

After applying the configuration with `just switch`, log out and back in to pick
up the `kvm` group. The first launch downloads a FEX root filesystem (about
1.3 GB) and Steam's client files. Game compatibility and performance vary under
translation; this setup has not yet been tested with a game on Asterion.

For diagnostics, run `steam-asahi --fex 'uname -m'` (expected: `x86_64`) and
`steam-asahi --fex 'vulkaninfo --summary'` to check GPU visibility.

## Peripheral support

The kernel's battery driver is working; UPower supplies its status to Noctalia.
CPU frequency scaling (`apple-cpufreq`/`schedutil`) and CPU idle already work.
Critical battery charge uses a clean power-off rather than unqualified suspend.
On 25 October, Noctalia detected the battery at 93% and one keyboard backlight.
The keyboard brightness helper passed as Lisa without sudo (77 → 51 → 77 out
of 255); Command+brightness keys adjust it and Command+Shift+K toggles it.

The standard Asahi AVD firmware and V4L2-request VAAPI bridge are enabled for
the video decoder. After activation, the AVD device bound successfully and
24 H.264 frames decoded through VAAPI matched software output exactly, including
when run as Lisa. Other advertised codecs have not been qualified. The ambient
light sensor also bound successfully and returned an illuminance reading.
Factory ambient-light calibration is recovered from this
Mac's existing ESP. The deterministic two-file archive is a private `requireFile`
input, retained with the installed calibration package for future rebuilds;
only its hash and extraction code belong in Git. Vega's backup is
`/Users/lisa/.local/state/asterion-gpu/factory/asterion-factory-calibration.tar`.

The 25 October source audit found m1n1 at the current integration revision.
Newer kernel T6030 fixes overlap this setup's static PMP and normalized UAT
integration. The newer Mesa branch changes kernel UAPI numbering and must be
qualified with a matching kernel; a package-only upgrade would break the tested
pair. The working GPU stack remains pinned together.

## Recovery

Keep the verified private RAM console payload on Vega. Tether it using the GPU
guide if normal boot fails. It retains the firmware framebuffer, Wi-Fi and the
file-key SSH access without loading native display/GPU automatically.

Older systemd-boot entries preserve old system generations, but the ESP's
m1n1/U-Boot image is shared. Restoring a generation alone does not restore the
old boot stack. Restore the saved ESP boot files or install the matching
known-good boot image from RAM recovery; preserve the firmware archives and
Apple partition map. A refused GPU firmware identity requires investigation.

Peripheral firmware is built from pinned byte ranges of Apple's J516s macOS
14.8.3 archive in `packages/asahi-firmware-j516s/`. The installed build does not
need impure `/boot` discovery. Factory ambient-light calibration is not supplied
by that archive. Do not publish generated Apple blobs or a binary cache
containing them.
