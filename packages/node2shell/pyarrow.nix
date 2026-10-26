{
  fetchurl,
  runCommand,
  unzip,
}: let
  wheel = fetchurl {
    # Built with Dockerfile.pyarrow; publish this exact artifact before deployment.
    url = "https://github.com/LisaScheers/Forge/releases/download/node2shell-2026-10-26/pyarrow-25.0.1-cp312-cp312-manylinux_2_28_x86_64.whl";
    sha256 = "b8b580ccd57d3cafcb1ffb2e7d4319975f0f56f81cd34cabc9e59b3ba3aab37e";
  };
in
  runCommand "pyarrow-node2shell" {
    nativeBuildInputs = [unzip];
    passthru.src = wheel;
  } ''
    mkdir -p "$out/pyarrow.libs"
    unzip -q ${wheel} -d "$out"
  ''
