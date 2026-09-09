# Asterion

`asterion` — “starry one.” NixOS on the 16-inch MacBook Pro with M3 Pro
(November 2023, Asahi `J516s`, SoC `T6030`). macOS and its recovery environment
remain installed alongside Linux.

## Status and limits

Checked 7 September 2026. Asahi enabled M3 installation on 6 September, behind
Expert mode. GPU acceleration, sleep and HDMI output are still unavailable.
The configuration disables sleep and lid-triggered suspend. Shut down before
putting the laptop in a bag; closing the lid leaves it running.

**A native niri desktop is currently blocked.** Niri 26.04, provided by Forge's
nixpkgs, rejects software EGL renderers in its DRM backend. Setting
`LIBGL_ALWAYS_SOFTWARE=1` or wlroots environment variables does not supply the
missing backend support. The Home Manager desktop is installed and configured,
but the system deliberately boots to a console login; do not install expecting
a working native niri session on M3 today.

The Asahi input is locked to `fb602d1f8c6d83dd652fecc3f468328f8864f0c1`:
kernel `7.1.12`, U-Boot `2026.04-2-asahi`; Forge's nixpkgs provides m1n1 `1.6.1`.
The kernel contains `apple/t6030-j516s.dtb`. Upstream Asahi hardware support does not guarantee
that every peripheral works with NixOS's particular userspace versions.

Validation on 7 September 2026: the installer ISO and standalone Home Manager
activation package built successfully on the ARM Linux builder. The desktop
build runs `niri validate`. The RAM installer booted on the J516s, and the full
system built on that Mac using its own firmware. Installation to the encrypted
root and existing Asahi ESP completed; bootloader entries and the initrd's LUKS
mapping, input drivers, and J516s firmware were checked. Lisa confirmed the
installed system's first boot after the installer was unmounted and the USB
cable disconnected. A subsequent `niri-session` attempt was reported to lock up
the display; no journal entries were captured. A working graphical session has
not been established, and the exact failure was not diagnosed.

References:

- [Asahi M3 announcement](https://asahilinux.org/2026/09/m2-episode-1/)
- [M3 feature matrix](https://asahilinux.org/docs/platform/feature-support/m3/)
- [NixOS Asahi installation guide](https://github.com/nix-community/nixos-apple-silicon/blob/fb602d1f8c6d83dd652fecc3f468328f8864f0c1/docs/uefi-standalone.md)
- [Niri software rendering issue](https://github.com/niri-wm/niri/issues/218)

## Build the installer

Run from this Forge checkout. Include the new files in your Git checkout before
using `.#…` flake references; Nix ignores untracked files. For an uncommitted local
copy, `path:.#…` includes them. Keep the same `flake.lock` for installer and target.

```sh
nix build path:.#packages.aarch64-linux.asterion-installer -o /tmp/asterion-installer -L
```

The ISO is in `/tmp/asterion-installer/iso/`. This builds Linux binaries, so on macOS
it needs an `aarch64-linux` builder with the `big-parallel` feature. On Vega,
start the existing OrbStack VM and advertise that feature for this build:

```sh
orbctl start nixos
nix build path:.#packages.aarch64-linux.asterion-installer \
  --builders 'ssh-ng://orbstack-builder aarch64-linux - 1 1 big-parallel' \
  -o /tmp/asterion-installer -L
```

Alternatively run the first build command inside an ARM Linux VM with Nix.
This does not activate a host configuration. Allow substantial disk
space and time for the Asahi kernel; upstream currently has no working cache
for it. An ordinary NixOS ARM ISO cannot substitute for this Asahi image.

Record the image checksum with
`shasum -a 256 /tmp/asterion-installer/iso/*.iso` on macOS. Changes to the
installer or locked inputs produce a different image and checksum.

Copy the ISO to a disposable USB drive. On macOS, inspect `diskutil list` and
replace `N` with the **external USB drive's** disk number, never the internal SSD:

```sh
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=/tmp/asterion-installer/iso/NAME.iso of=/dev/rdiskN bs=4m
sync
diskutil eject /dev/diskN
```

Replace `NAME.iso` with the actual filename. `dd` erases the selected USB drive.
Prepare a separate copy of this Forge checkout, including `flake.lock`, so it
can be copied to the installed root later. Do not assume this branch is on main.

## Prepare Apple's boot environment

Back up macOS first. Keep macOS, the initial iBoot container and the final
RecoveryOS container. Do not use Forge's `nixos-anywhere` recipes, disko, or a
whole-disk automatic partitioner on this Mac.

In macOS Terminal, run the command from Asahi's M3 announcement:

```sh
curl -L https://alx.sh/ | EXPERT=1 sh
```

1. Confirm that the installer identifies the M3 Pro MacBook correctly.
2. Resize macOS using Asahi's installer. Reserve at least 80 GiB for Linux;
   more is useful for development and local Nix builds.
3. Choose **UEFI environment only**, name it **Asterion**, and leave room for
   the Linux root partition. Let Asahi select the supported firmware/stub
   version for M3; do not force the old M1/M2 macOS 13.5 instructions.
4. Complete the recovery and security-policy prompts exactly as the installer
   directs. This step requires the Mac's owner credentials and physical access.
5. Shut down, insert the USB installer and select Asterion by holding the power
   button. If U-Boot selects the wrong device, interrupt its countdown, run
   `eficonfig`, move USB first in the boot order, save, then run `boot`.

If the current Asahi installer does not offer UEFI for this model, stop here.
Do not force another model or replace the existing macOS partitions.

## Install without a USB drive: tethered boot

This alternative uses a USB-C **data cable** between a development Mac and the
M3 Mac. Complete the Asahi UEFI preparation above first. The cable does not
replace Apple's owner-authenticated recovery step. This path is experimental
until tested on the target; successful builds do not establish hardware boot
success.

Validation on 7 September 2026: the tethered payload built successfully (24 MiB
compressed kernel, 580 MiB initrd). Both gzip streams passed integrity checks;
the initrd contains `init` and the embedded Nix store, and the generated fstab
uses RAM filesystems. The macOS shell passed proxy-import and AArch64 assembly
checks. On J516s hardware, m1n1 chainloading, the full USB payload transfer,
kernel decompression and handoff completed. Lisa confirmed that the live
installer loaded on the target. Installation to disk subsequently completed,
and Lisa confirmed the installed system's first boot. A USB serial disconnect
after `Preparing to run next stage` is expected when leaving m1n1; use the
target screen to distinguish a successful Linux boot from a subsequent failure.

The tethered installer has its complete Nix store in RAM. It does not look for
the ISO or mount a USB drive. It mounts the Asahi-selected ESP read-only to
extract firmware into RAM, and does not partition or install automatically.
Connect to Wi-Fi with `nmtui` after boot; the m1n1 cable is not an Internet
connection. Keep the target connected to power.

The initial hardware boot exposed a firmware-extraction failure: the RAM
installer omitted FAT character-set modules from its initrd, so mounting the
ESP during activation failed. The configuration now explicitly loads `vfat`,
`nls_cp437` and `nls_iso8859-1` before that step. If diagnosing an older image,
inspect `journalctl -b -u initrd-nixos-activation`; absent
`/lib/firmware/brcm` indicates that Wi-Fi firmware has not been extracted.
Load the missing charset modules and rerun that image's firmware extraction
hook, then reload `brcmfmac`. Do not format the ESP to address this mount error.
The corrected payload built successfully; inspection of its initrd verified
both charset module files and their early-load configuration. Loading those
modules on the target resolved the mount failure, exposing a second issue:
`asahi-fwextract 0.8.0` stops at `assert not props` in its Wi-Fi parser.
Both installers now pin the extractor to Asahi's September 1, 2026 revision,
which handles newer Apple firmware filenames. The tethered installer first uses
`vendorfw/firmware.cpio` from the ESP when present, falling back to extraction
from `asahi/`. The updated RAM payload built successfully. A synthetic filename
check reproduced the old parser's assertion and verified that the pinned parser
skips the generic file while retaining Jura firmware. Hardware verification of
the updated extractor remains pending. On J516s, loading the existing ESP
archive into RAM succeeded: the driver loaded BCM4388 firmware and calibration
data. Restarting `iwd` and `NetworkManager` after the driver reload restored
Wi-Fi; Internet access and DNS were verified.

For an already running installer, an existing archive can restore firmware
without rebooting. With the confirmed Asahi ESP mounted read-only at `/run/esp`,
run this only if `/run/esp/vendorfw/firmware.cpio` exists:

```sh
mkdir -p /run/fw /lib/firmware
(cd /run/fw && cpio -id --quiet --no-absolute-filenames < /run/esp/vendorfw/firmware.cpio) &&
  cp -r /run/fw/vendorfw/. /lib/firmware/
modprobe -r brcmfmac
modprobe brcmfmac
systemctl restart iwd
systemctl restart NetworkManager
nmcli device
```

If a Wi-Fi interface appears, use `nmtui` to connect. If no archive exists,
use the rebuilt installer with the updated extractor.

### Prepare the host

From this Forge checkout on the development Mac:

```sh
nix build path:.#packages.aarch64-linux.asterion-tethered-installer \
  --builders 'ssh-ng://orbstack-builder aarch64-linux - 1 1 big-parallel' \
  -o /tmp/forge-asterion-tether -L
nix develop path:.#asahi-tether
```

The shell provides Python, m1n1's proxy client, LLVM and picocom without changing
the host's system configuration. Client sources and `m1n1.bin` use the same
nixpkgs-pinned m1n1 release. The client reserves a 2 GiB target-memory heap to
accommodate the full installer and the loader's 512 MiB kernel reservation.

The output contains `Image.gz`, `t6030-j516s.dtb`, `initrd.gz`, `m1n1.bin` and
`bootargs`. Use these files together. The device tree is specifically for the
16-inch M3 Pro MacBook Pro, J516s.

### Enable the target's proxy mode

First record this installation's EFI partition UUID. At the target's U-Boot
`=>` prompt, run these read-only commands and save the resulting UUID:

```text
fdt addr ${fdtcontroladdr}
fdt print /chosen asahi,efi-system-partition
```

The early m1n1 proxy runs before stage 1 reads that setting, and chainloading a
plain m1n1 does not preserve it. The host loader below passes it explicitly.
Do not substitute the APFS volume UUID or guess a partition number.

Follow [Asahi's tethered boot guide](https://asahilinux.org/docs/sw/tethered-boot/#enabling-the-backdoor-proxy-mode).
Make Asterion the default startup volume first. Shut down the target, hold its
power button until startup options appear, then choose **Options → Continue**.
In Recovery, open **Utilities → Terminal** and run:

```sh
csrutil disable
```

Select **Asterion / the Asahi installation**, authenticate, and after success:

```sh
nvram boot-args=-v
shutdown -h now
```

This policy change is per OS. Do not select your regular macOS volume. A pairing
error means the recovery environment is not paired with the default OS; fix
the startup selection before proceeding. Leave the target off for now.

### Catch the USB proxy and send the installer

Connect the Macs directly. In the development Mac's `asahi-tether` shell, start:

```sh
bash "$M1N1_SOURCE/proxyclient/tools/picocom-sec.sh"
```

Now start the M3 Mac into Asterion. The listener opens the secondary serial
port during m1n1's five-second wait and keeps it in proxy mode. If you reach
U-Boot again, the proxy was not caught; recheck recovery setup and device names.
Leave this terminal running.

The usual macOS device names are `/dev/cu.usbmodemP_01` (primary) and
`/dev/cu.usbmodemP_03` (secondary), but they can differ. Run
`python3 -m serial.tools.list_ports -v` in another tether shell to inspect actual
names. If necessary, set `M1N1DEVICE` to the secondary port **only for the
listener command**. The loader commands below require the primary port.
On the first J516s tested here the names were
`/dev/cu.usbmodemLD6WQ5P9341` and `/dev/cu.usbmodemLD6WQ5P9343`; the upstream
listener's default `P_03` did not detect them. For such a device, start the
listener with its actual secondary path before rebooting:

```sh
M1N1DEVICE=/dev/cu.usbmodemLD6WQ5P9343 \
  bash "$M1N1_SOURCE/proxyclient/tools/picocom-sec.sh"
```

Open a second terminal in the same Forge checkout:

```sh
nix develop path:.#asahi-tether
export M1N1DEVICE=/dev/cu.usbmodemP_01
asterion_payload=/tmp/forge-asterion-tether

python3 "$M1N1_SOURCE/proxyclient/tools/chainload.py" -r "$asterion_payload/m1n1.bin"
```

Wait for `Proxy is alive again`. This chainloads the matching m1n1 into RAM;
it does not replace the installed bootloader. Then send the installer:

```sh
python3 scripts/asterion-tether-boot.py "$asterion_payload" \
  --device "$M1N1DEVICE" --esp-uuid UUID-FROM-U-BOOT
```

The transfer can take several minutes. This boots Linux directly, without the
m1n1 hypervisor. Use the **target's screen and keyboard** for the live console;
do not expect the secondary port to supply a Linux console in this mode.
Proceed with the next section once the `nixos` console appears. If it fails,
capture the loader output and the target's last visible message before retrying.

## Install from the live console

Become root with `sudo -i`. Connect using `nmtui` or USB Ethernet. An external
USB keyboard is useful if built-in input has a firmware problem.

Verify the machine and identify **this installation's** EFI partition:

```sh
tr '\0' '\n' < /proc/device-tree/compatible
esp_uuid=$(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition)
esp=/dev/disk/by-partuuid/$esp_uuid
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,LABEL,PARTUUID,MOUNTPOINTS
test -b "$esp"
blkid "$esp"
```

The compatibility list must include `apple,j516s`. The selected ESP must be the
FAT partition created for Asterion, with Asahi's boot files, not an arbitrary
EFI partition. Stop if either check disagrees.

### Create only the new Linux root

Use `parted /dev/nvme0n1 unit s print free` to inspect the partition map. In an
interactive `parted /dev/nvme0n1` session, set `unit s`, then use `mkpart` to create
one partition named `asterion-root` within the specific free region left by
Asahi, using its start and end sectors. Do not create a new partition table,
move existing partitions, or consume a different free region. Run `print` again
and verify the resulting boundaries before `quit`.

After the kernel sees the new partition:

```sh
udevadm settle
root_part=/dev/disk/by-partlabel/asterion-root
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,MOUNTPOINTS "$root_part"
```

Confirm that `root_part` is exactly the newly created, empty Linux partition.
The next two formatting commands destroy its contents. They must never point
to the whole NVMe drive or any existing Apple partition.

```sh
cryptsetup luksFormat --type luks2 "$root_part"
cryptsetup open "$root_part" asterion-root
mkfs.ext4 -L asterion /dev/mapper/asterion-root
mount /dev/mapper/asterion-root /mnt
```

Use a strong passphrase that you can type with the console's US keyboard layout.
LUKS encrypts Linux's root; the boot partition remains unencrypted. Keep a LUKS
header backup on separate protected storage after installation.

### Mount the existing ESP and extract firmware

Assign a filesystem label to the existing Asterion ESP; **do not format it**:

```sh
fatlabel "$esp" ASTERIONEFI
mkdir -p /mnt/boot
mount -o umask=0077 "$esp" /mnt/boot
ls /mnt/boot
```

Keep its `asahi/`, `m1n1/` and other existing files. If the installer did not
already create `vendorfw/firmware.cpio`, extract it from the Asahi files:

```sh
if ! test -s /mnt/boot/vendorfw/firmware.cpio; then
  mkdir -p /mnt/boot/vendorfw
  asahi-fwextract /mnt/boot/asahi /mnt/boot/vendorfw
fi
test -s /mnt/boot/vendorfw/firmware.cpio
```

This archive contains Apple's non-redistributable firmware. Keep it on the Mac;
do not commit it, upload it, or publish a system closure containing it. Asahi's
NixOS module discovers it at `/mnt/boot/vendorfw` during installation and
`/boot/vendorfw` afterwards. `--impure` allows this local path discovery.

### Install Forge and create the login password

Copy the prepared Forge checkout into `/mnt/etc/nixos/forge`. Ensure hidden files
and `flake.lock` are included. Forge has private Git inputs: the build needs
authorized access to those inputs or their already-fetched store paths. If a
fetch fails, arrange Git access before proceeding; don't remove the lock file.

```sh
cd /mnt/etc/nixos/forge
nix --extra-experimental-features 'nix-command flakes' build \
  --impure path:.#nixosConfigurations.asterion.config.system.build.toplevel \
  --store /mnt --extra-substituters 'auto?trusted=1' \
  --out-link /mnt/asterion-system -L
nixos-install --system "$(readlink /mnt/asterion-system)" --no-root-passwd
nixos-enter --root /mnt -c 'passwd lisa'
```

Root login is locked. **Do not skip `passwd lisa`**: Lisa needs a password for
the console and sudo. The LUKS passphrase is independent of the login password.
`--store /mnt` keeps downloaded packages and build outputs on the SSD instead
of exhausting the RAM installer's temporary filesystem.

Before reboot, verify:

```sh
test -s /mnt/boot/m1n1/boot.bin
test -s /mnt/boot/EFI/BOOT/BOOTAA64.EFI
ls /mnt/boot/loader/entries
nixos-enter --root /mnt -c 'passwd --status lisa'
```

The password status must be `P`. Then `sync`, unmount with `umount -R /mnt`, close
the mapping with `cryptsetup close asterion-root`, and reboot. Remove the USB.
Use Apple's boot picker to choose macOS or Asterion.

## Rebuilds and recovery

On Asterion, from `/etc/nixos/forge`:

```sh
sudo nixos-rebuild build --impure --flake path:.#asterion
sudo nixos-rebuild boot --impure --flake path:.#asterion
sudo reboot
```

Home Manager configuration is activated as part of NixOS. Use
`boot` for kernel/boot-stack changes so the generation takes effect together on
reboot. Asterion has no auto-update timer or deploy-rs node. Enroll Tailscale
manually with `sudo tailscale up` if wanted; no enrollment key is embedded.

Keep the USB installer until several successful boots. For repair, boot it,
unlock `asterion-root`, mount root and its ESP at `/mnt` and `/mnt/boot`, then
build the last known-good Forge revision and run `nixos-install --system ...`
again. Preserve firmware and the Apple partition map.

Older systemd-boot entries can restore a system generation, but m1n1/U-Boot in
the ESP are shared across generations. If a boot-stack update prevents reaching
that menu, use the USB installer to reinstall a known-good generation's boot
files. Don't delete the ESP or Apple recovery partitions as a first repair step.

## Observatory desktop

The selected design is **A · Observatory**: black background, a dense top bar,
white focus ring, three named workspaces and columns that default to one third
of the screen. Animations are disabled. Home Manager owns niri's KDL, all desktop
configuration files, and the session services. Edit
`flake-parts/homes/lisa@asterion/`, then rebuild NixOS; generated files in
`~/.config` are not the source of truth.

The desktop can be built and validated independently of the Mac's firmware:

```sh
nix build 'path:.#checks.aarch64-linux.home-lisa@asterion' --no-link
```

The matching standalone output is `homeConfigurations."lisa@asterion"`.
On the installed Mac, keep using NixOS rebuilds to activate the system and home
configuration together.

| Component | Configuration |
| --- | --- |
| niri | Validated KDL, touchpad gestures, US layout, 2× scale for `eDP-1`, named workspaces |
| Waybar | Top bar: workspaces, window title, tray, network, volume, battery, clock |
| swaylock | Black lock screen; NixOS provides PAM authentication |
| swayidle | Lock after five idle minutes and on logind lock; no suspend or monitor-power timeout |
| Mako | Top-right notifications; critical notifications remain until dismissed |
| polkit | GNOME authentication agent; system polkit supplied by the NixOS niri module |
| swaybg | Solid black wallpaper, managed as a session service |
| Foot / Fuzzel | Terminal and application launcher |
| Xwayland Satellite | Niri launches it on demand for X11 applications |
| Portals / keyring | NixOS supplies file chooser, screencasting integration and GNOME Keyring |

Once Asahi's GPU support or niri's software-rendering support makes the native
session viable, log in on a TTY as Lisa and run `niri-session`. Use that command
to start the managed graphical session: running bare `niri` does not start the
same systemd services. Do not run it as root. There is no automatic graphical
login while the rendering limitation remains. Startup may leave the display
unresponsive instead of returning to the console, as reported on this Mac.
Try Ctrl+Alt+F2 (Control+Option+F2, with Fn if needed, on the Mac keyboard), log
in as Lisa, and run `systemctl --user stop niri.service` followed by
`pkill -x niri`. Inspect `journalctl --user -u niri -b` if entries are available.

`Mod` is the Mac's Command/Super key in a native session:

| Shortcut | Action |
| --- | --- |
| Mod+Return / Mod+D | Terminal / launcher |
| Mod+H/J/K/L | Focus left / down / up / right |
| Mod+Shift+H/J/K/L | Move column or window |
| Mod+1/2/3 | Code / web / chat workspace |
| Mod+Shift+1/2/3 | Move column to workspace |
| Mod+R / Mod+F / Mod+Shift+F | Cycle width / maximize column / fullscreen |
| Mod+V / Mod+O | Toggle floating / overview |
| Mod+Escape | Lock |
| Mod+N | Dismiss notification |
| Mod+Shift+S | Region screenshot |
| Mod+Shift+Q / Mod+Shift+E | Close window / exit session (with confirmation) |
| Mod+Shift+/ | Shortcut help |

Volume and microphone keys use PipeWire. PrintScreen also takes a region screenshot.
Network and volume modules open their configuration tools when clicked.
The lid requests a session lock while leaving the machine awake. Logind's lock
request applies to graphical sessions; a plain console has no swaylock process.

After the first supported graphical boot, verify `swaylock` unlocks with Lisa's
password, `loginctl lock-session` locks the screen, and the idle timeout works.
Check services with:

```sh
systemctl --user status waybar mako swayidle swaybg polkit-gnome
niri validate
niri msg outputs
```

If the built-in display is named differently from `eDP-1`, update the output
stanza using the name from `niri msg outputs`. Kernel/input/audio support and
real screen-lock behavior still need to be tested on the physical Mac.

To refresh vendor firmware, run Asahi's installer from macOS and choose its
firmware rebuild operation, then rebuild NixOS. To update NixOS Asahi support,
update the `nixos-apple-silicon` input intentionally and recheck the M3/niri
limitations before enabling a graphical login.
