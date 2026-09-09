"""Boot the J516s RAM installer from the asahi-tether Nix shell."""

import argparse
import os
from pathlib import Path
import runpy
import sys
from uuid import UUID


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("payload", type=Path)
    parser.add_argument("--esp-uuid", required=True, type=UUID)
    parser.add_argument("--device", required=True, help="Primary m1n1 serial port")
    args = parser.parse_args()

    for name in ("Image.gz", "t6030-j516s.dtb", "initrd.gz", "bootargs"):
        if not (args.payload / name).is_file():
            parser.error(f"Missing payload file: {args.payload / name}")
    source = os.environ.get("M1N1_SOURCE")
    if source is None:
        parser.error("Run inside: nix develop path:.#asahi-tether")

    os.environ["M1N1DEVICE"] = args.device
    proxyclient = Path(source) / "proxyclient"
    sys.path.insert(0, str(proxyclient))
    from m1n1.setup import p, u

    if u.adt.getprop("target-type") != "J516s":
        parser.error("This payload requires a J516s (16-inch M3 Pro MacBook Pro)")

    # The early proxy runs before stage 1 reads its appended configuration.
    # A plain m1n1 chainload also loses that configuration. Restore the ESP
    # reference explicitly so the live installer can extract target firmware.
    p.kboot_set_chosen("asahi,efi-system-partition", str(args.esp_uuid))
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
