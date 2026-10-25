"""Boot the J516s RAM installer from the asahi-tether Nix shell."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import sys
from uuid import UUID


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("payload", type=Path)
    parser.add_argument("--esp-uuid", type=UUID)
    parser.add_argument("--device", help="Primary m1n1 serial port")
    parser.add_argument("--check", action="store_true", help="Validate payload without connecting to the target")
    args = parser.parse_args()

    for name in ("Image.gz", "t6030-j516s.dtb", "initrd.gz", "bootargs"):
        if not (args.payload / name).is_file():
            parser.error(f"Missing payload file: {args.payload / name}")

    manifest_path = args.payload / "manifest.json"
    gpu_test = manifest_path.exists() or (args.payload / "SHA256SUMS").exists() or "M1N1_SOURCE_REV" in os.environ
    if gpu_test:
        if not manifest_path.is_file():
            parser.error("GPU payload is missing manifest.json")
        manifest = json.loads(manifest_path.read_text())
        if manifest["kind"] != "asterion-gpu-test" or manifest["target"] != "J516s":
            parser.error("Unsupported test payload")
        if os.environ.get("M1N1_SOURCE_REV") != manifest["m1n1Revision"]:
            parser.error("GPU payload requires its matching nix develop path:.#asahi-gpu-tether shell")
        expected_files = {"Image.gz", "t6030-j516s.dtb", "initrd.gz", "m1n1.bin", "bootargs", "manifest.json"}
        checked_files = set()
        for entry in (args.payload / "SHA256SUMS").read_text().splitlines():
            digest, name = entry.split("  ", 1)
            if name not in expected_files or name in checked_files:
                parser.error(f"Unexpected or duplicate checksum entry: {name}")
            with (args.payload / name).open("rb") as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            if actual != digest:
                parser.error(f"Payload checksum mismatch: {name}")
            checked_files.add(name)
        if checked_files != expected_files:
            parser.error("Incomplete payload checksum manifest")
        print(json.dumps(manifest, indent=2))
    if args.check:
        print("Payload checked; no target connection made.")
        return
    if args.esp_uuid is None or args.device is None:
        parser.error("Boot requires --device and --esp-uuid")
    if not sys.stdin.isatty():
        parser.error("Boot from an interactive terminal; m1n1's Linux loader requires a PTY")

    source = os.environ.get("M1N1_SOURCE")
    if source is None:
        parser.error("Run inside: nix develop path:.#asahi-tether")

    os.environ["M1N1DEVICE"] = args.device
    proxyclient = Path(source) / "proxyclient"
    sys.path.insert(0, str(proxyclient))
    from m1n1.setup import p, u

    if u.adt.getprop("target-type") != "J516s":
        parser.error("This payload requires a J516s (16-inch M3 Pro MacBook Pro)")

    # linux.py allocates the compressed payload and a 512 MiB kernel buffer
    # before the initramfs. An older open shell can still have a smaller heap.
    required_heap = sum((args.payload / name).stat().st_size for name in
                        ("Image.gz", "t6030-j516s.dtb", "initrd.gz")) + 528 * 1024 * 1024
    if required_heap > u.heap_size:
        parser.error("Payload exceeds the proxy heap; reopen the matching Nix shell")

    # The early proxy runs before stage 1 reads its appended configuration.
    # A plain m1n1 chainload also loses that configuration. Restore the ESP
    # reference explicitly so the live installer can extract target firmware.
    p.kboot_set_chosen("asahi,efi-system-partition", str(args.esp_uuid))
    if gpu_test:
        # The handoff checks ASCII '1', not a device-tree u32. These markers
        # enable the pinned firmware handoff during kboot_prepare_dt().
        p.kboot_set_chosen("asahi,t6030-dcp", "1")
        p.kboot_set_chosen("asahi,t6030-gpu", "1")
    loader = proxyclient / "tools/linux.py"
    sys.argv = [
        str(loader),
        "-b",
        (args.payload / "bootargs").read_text().strip(),
        str(args.payload / "Image.gz"),
        str(args.payload / "t6030-j516s.dtb"),
        str(args.payload / "initrd.gz"),
    ]
    runpy.run_path(str(loader), run_name="__main__")


if __name__ == "__main__":
    main()
