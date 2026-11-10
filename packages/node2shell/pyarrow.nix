{
  fetchurl,
  runCommand,
  unzip,
}: let
  wheel = fetchurl {
    # Upstream 26.0.1 bundles Brotli 1.2.1, including the decoder fix.
    url = "https://files.pythonhosted.org/packages/d3/79/e2fc9b1317b7a21e7bcd57eb035cac3fe72f47af3efe2ec3b4dea9a08a04/pyarrow-26.0.1-cp312-cp312-manylinux_2_28_x86_64.whl";
    sha256 = "c718bf97a92a6dea97fd1062c3b9f9e2e83cb9cc926e752289fa4ffff41738f9";
  };
in
  runCommand "pyarrow-node2shell" {
    nativeBuildInputs = [unzip];
    passthru.src = wheel;
  } ''
    mkdir -p "$out/pyarrow.libs"
    unzip -q ${wheel} -d "$out"
  ''
