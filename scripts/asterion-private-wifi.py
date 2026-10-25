"""Add Lisa IOT credentials to a private copy of Asterion's RAM payload.

Run after the public Nix build. Neither the password nor the derived PSK enters
the source tree or Nix store; the resulting private image contains the PSK.
"""

import argparse
import base64
import getpass
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import sys
from uuid import uuid4
import warnings


FILES = ("Image.gz", "t6030-j516s.dtb", "initrd.gz", "m1n1.bin", "bootargs", "manifest.json")
SSID = "Lisa IOT"


def cpio_entry(name, data, mode):
    filename = name.encode() + b"\0"
    fields = [0, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(filename), 0]
    entry = b"070701" + b"".join(f"{value:08x}".encode() for value in fields) + filename
    entry += b"\0" * (-len(entry) % 4)
    entry += data
    return entry + b"\0" * (-len(data) % 4)


def create_payload(base, output, password, ssh_public_key=None):
    manifest = json.loads((base / "manifest.json").read_text())
    if manifest.get("kind") != "asterion-gpu-test" or manifest.get("target") != "J516s" or manifest.get("privateWifiSupport") is not True:
        raise ValueError("Base image lacks the private Wi-Fi bootstrap service")
    if not 8 <= len(password.encode()) <= 63:
        raise ValueError("WPA2 passphrase must contain 8 to 63 bytes")
    psk = hashlib.pbkdf2_hmac("sha1", password.encode(), SSID.encode(), 4096, 32).hex()
    profile = (
        f"[connection]\nid=asterion-wifi\nuuid={uuid4()}\ntype=wifi\nautoconnect=true\n"
        f"[wifi]\nmode=infrastructure\nssid={SSID}\n"
        f"[wifi-security]\nkey-mgmt=wpa-psk\npsk={psk}\npsk-flags=0\n"
        "[ipv4]\nmethod=auto\n[ipv6]\nmethod=auto\n"
    ).encode()
    iwd_profile = f"[Security]\nPreSharedKey={psk}\n[Settings]\nAutoConnect=true\n".encode()
    archive = cpio_entry("asterion-wifi.nmconnection", profile, 0o100600)
    archive += cpio_entry("asterion-wifi.psk", iwd_profile, 0o100600)
    if ssh_public_key is not None:
        if manifest.get("privateSshSupport") is not True:
            raise ValueError("Base image lacks the private SSH bootstrap service")
        fields = ssh_public_key.strip().split()
        if len(ssh_public_key.splitlines()) != 1 or len(fields) < 2 or fields[0] != "ssh-ed25519":
            raise ValueError("Supply one Ed25519 public key")
        decoded = base64.b64decode(fields[1], validate=True)
        if len(decoded) != 51 or not decoded.startswith(b"\0\0\0\x0bssh-ed25519\0\0\0\x20"):
            raise ValueError("Invalid Ed25519 public key")
        archive += cpio_entry("asterion-test-authorized-key", (ssh_public_key.strip() + "\n").encode(), 0o100600)
    archive += cpio_entry("TRAILER!!!", b"", 0)
    archive += b"\0" * (-len(archive) % 512)

    output.mkdir(mode=0o700)
    try:
        for name in FILES:
            if name == "initrd.gz":
                continue
            destination = output / name
            with destination.open("xb") as stream, (base / name).open("rb") as source:
                destination.chmod(0o600)
                shutil.copyfileobj(source, stream)
        initrd = output / "initrd.gz"
        with initrd.open("xb") as stream, (base / "initrd.gz").open("rb") as source:
            initrd.chmod(0o600)
            shutil.copyfileobj(source, stream)
            stream.write(gzip.compress(archive, mtime=0))
        manifest["privateWifi"] = True
        manifest["privateSsh"] = ssh_public_key is not None
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        with (output / "SHA256SUMS").open("x") as stream:
            (output / "SHA256SUMS").chmod(0o600)
            for name in FILES:
                with (output / name).open("rb") as payload_file:
                    digest = hashlib.file_digest(payload_file, "sha256").hexdigest()
                stream.write(f"{digest}  {name}\n")
    except BaseException:
        shutil.rmtree(output)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ssh-public-key", type=Path, help="Public key whose private half stays on Vega")
    args = parser.parse_args()
    if not sys.stdin.isatty():
        parser.error("Use an interactive terminal for the password prompt")
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        password = getpass.getpass("Wi-Fi password (not echoed): ")
    ssh_public_key = args.ssh_public_key.read_text() if args.ssh_public_key else None
    create_payload(args.base, args.output, password, ssh_public_key)
    print(f"Private Wi-Fi payload created: {args.output}")


if __name__ == "__main__":
    main()
