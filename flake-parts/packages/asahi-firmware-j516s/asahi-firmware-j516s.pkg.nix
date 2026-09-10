{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  curl,
  cacert,
  python3,
  _7zz,
  lzfse,
}: let
  version = "14.8.3";
  # Asahi's J516s target uses this OTA ZIP, not a full restore IPSW.
  url = "https://updates.cdn-apple.com/2025FallFCS/patches/089-71124/49AD260A-D47F-4B5E-A793-30446187196E/com_apple_MobileAsset_MacSoftwareUpdate/f6d1ac9149f6a06401ff87fae5b262c420bfc5f7.zip";
  ranges = builtins.fromJSON (builtins.readFile ./ranges.json);
  fetchRange = name: entry:
    stdenvNoCC.mkDerivation {
      name = "asahi-${version}-j516s-${name}.zip-entry";
      nativeBuildInputs = [curl];
      # Pin the compressed entry bytes. Refuse a CDN that ignores Range instead
      # of silently downloading the entire 13.6 GB archive.
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = entry.hash;
      impureEnvVars = lib.fetchers.proxyImpureEnvVars;
      preferLocalBuild = true;
      buildCommand = ''
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        status=$(curl --fail --location --retry 3 \
          --proto '=https' --proto-redir '=https' \
          --range ${toString entry.start}-${toString (entry.start + entry.length - 1)} \
          --max-filesize ${toString entry.length} \
          --dump-header headers --write-out '%{http_code}' \
          --output "$out" '${url}')
        test "$status" = 206
        test "$(wc -c < "$out")" -eq ${toString entry.length}
        tr -d '\r' < headers | grep -Fxi \
          'content-range: bytes ${toString entry.start}-${toString (entry.start + entry.length - 1)}/13637436385'
      '';
    };
  sources = lib.mapAttrs fetchRange ranges;
  extractor = fetchFromGitHub {
    owner = "AsahiLinux";
    repo = "asahi-installer";
    rev = "99dff2e968dafcabc2a940865b051e91ffcfafd3";
    hash = "sha256-IbGH5pn65XL7tIbvwYLk1GLjjnp7wI1DV/4e94cySCc=";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "asahi-firmware-j516s";
    inherit version;
    nativeBuildInputs = [python3 _7zz];
    dontUnpack = true;
    buildCommand = ''
      cp -r ${extractor} extractor
      chmod -R u+w extractor
      substituteInPlace extractor/asahi_firmware/img4.py \
        --replace-fail 'liblzfse.so' '${lzfse}/lib/liblzfse.so'
      export PYTHONPATH="$PWD/extractor/src"
      export PYTHONDONTWRITEBYTECODE=1
      python ${./extract.py} ${./ranges.json} \
        ${sources.recovery} ${sources.kernel} ${sources.multitouch} "$out"
      # Match the independently verified extraction from the full Apple archive.
      echo "ae4133960d4815b225f2ff1a6bfc6df2fe22ad82324ba07a8ec2142c110c862a  $out/firmware.cpio" | sha256sum -c -
    '';
    passthru = {inherit sources;};
    meta = {
      description = "Asahi J516s peripheral firmware from selected Apple 14.8.3 archive ranges";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
      # Apple firmware must not be published in a binary cache.
      hydraPlatforms = [];
    };
  }
