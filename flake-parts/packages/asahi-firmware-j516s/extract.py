"""Package the three pinned J516s OTA entries without mounting a disk image."""

import hashlib
import json
import pathlib
import shutil
import struct
import subprocess
import sys
import zlib

from asahi_firmware.bluetooth import BluetoothFWCollection
from asahi_firmware.core import FWPackage
from asahi_firmware.isp import ISPFWCollection
from asahi_firmware.kernel import KernelFWCollection
from asahi_firmware.multitouch import MultitouchFWCollection
from asahi_firmware.wifi import WiFiFWCollection
from util import PBZX


def unpack_entry(source, target, entry):
    """Nix verifies the compressed hash; also check the ZIP length and CRC."""
    decoder = zlib.decompressobj(-15) if entry["compression"] == 8 else None
    if entry["compression"] not in (0, 8):
        raise ValueError("Unsupported ZIP compression")
    size = crc = 0
    with open(source, "rb") as src, target.open("wb") as dst:
        while block := src.read(1024 * 1024):
            if decoder is not None:
                block = decoder.decompress(block)
            dst.write(block)
            size += len(block)
            crc = zlib.crc32(block, crc)
    if decoder is not None and (not decoder.eof or decoder.unused_data):
        raise ValueError("Incomplete or trailing ZIP stream")
    if size != entry["size"] or crc != entry["crc32"]:
        raise ValueError(f"ZIP checksum mismatch: {entry['path']}")


def unpack_recovery(source, target):
    with source.open("rb") as src, target.open("wb") as dst:
        if src.read(8) != b"BXDIFF50":
            raise ValueError("Expected the OTA BaseSystem container")
        src.read(8)
        size, control_size, _ = struct.unpack("<3Q", src.read(24))
        if control_size != 0:
            raise ValueError("BaseSystem requires a base image")
        expected = src.read(20)
        stream = PBZX(src, size)
        digest = hashlib.sha1()
        written = 0
        while block := stream.read(16 * 1024 * 1024):
            dst.write(block)
            digest.update(block)
            written += len(block)
        if written != size or digest.digest() != expected:
            raise ValueError("BaseSystem checksum mismatch")


def main():
    metadata, recovery, kernel, multitouch, destination = sys.argv[1:]
    entries = json.loads(pathlib.Path(metadata).read_text())
    raw = pathlib.Path("raw")
    raw.mkdir()
    for name, source in (("recovery", recovery), ("kernel", kernel), ("multitouch", multitouch)):
        unpack_entry(source, raw / name, entries[name])
    unpack_recovery(raw / "recovery", raw / "BaseSystem.dmg")

    # The pinned Apple image uses chains of relative Wi-Fi symlinks. Allow
    # those links, then ensure every extracted link resolves within recovery.
    subprocess.run([
        "7zz", "x", "-y", "-snld20", str(raw / "BaseSystem.dmg"), "-orecovery",
        "usr/share/firmware/wifi", "usr/share/firmware/bluetooth", "usr/sbin/appleh13camerad",
    ], check=True)
    root = pathlib.Path("recovery").resolve()
    for path in root.rglob("*"):
        if path.is_symlink():
            path.resolve().relative_to(root)

    fud = raw / "fud_firmware" / "j516s"
    fud.mkdir(parents=True)
    (raw / "multitouch").rename(fud / "Multitouch.im4p")
    output = pathlib.Path(destination)
    output.mkdir()
    package = FWPackage(str(output))
    for collection in (
        WiFiFWCollection(str(root / "usr/share/firmware/wifi")),
        BluetoothFWCollection(str(root / "usr/share/firmware/bluetooth")),
        MultitouchFWCollection(str(raw / "fud_firmware")),
        ISPFWCollection(str(root / "usr/sbin")),
        KernelFWCollection(str(raw / "kernel")),
    ):
        files = sorted(collection.files())
        if not files:
            raise ValueError(f"No firmware from {type(collection).__name__}")
        package.add_files(files)
    package.close()
    # Keep the output limited to what peripheralFirmwareDirectory consumes,
    # plus the manifest for inspecting and verifying the packaged firmware.
    (output / "firmware.tar").unlink()
    shutil.rmtree(output / "u-boot")


if __name__ == "__main__":
    main()
