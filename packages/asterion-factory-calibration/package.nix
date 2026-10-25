{
  requireFile,
  runCommand,
  gnutar,
}: let
  calibration = requireFile {
    name = "asterion-factory-calibration.tar";
    sha256 = "da2afbf88850aaa05eaff8ce00024c44ce885a94633ff1672f39db48e07e7c26";
    message = ''
      Asterion's factory calibration archive is required. Recover only its ALS
      and HmCA calibration from the existing Asahi ESP, then import the private
      archive with: nix-store --add-fixed sha256 asterion-factory-calibration.tar
      Keep the archive outside Git and public binary caches.
    '';
  };
in
  runCommand "asterion-factory-calibration" {nativeBuildInputs = [gnutar];} ''
    mkdir -p "$out/lib/firmware"
    tar -xf ${calibration} --no-same-owner -C "$out/lib/firmware"
    test -s "$out/lib/firmware/apple/aop-als-cal.bin"
    test -s "$out/lib/firmware/apple/HmCA-0701012D2BA97057"
    test "$(find "$out/lib/firmware" -type f | wc -l)" = 2
    # Keep the private requireFile input available for subsequent local rebuilds.
    mkdir -p "$out/nix-support"
    echo ${calibration} > "$out/nix-support/factory-calibration-source"
  ''
