{
  inputs,
  lib,
  ...
}: let
  patchedBrotli = pkgs:
    if lib.versionAtLeast pkgs.brotli.version "1.2.1"
    then pkgs.brotli
    else
      pkgs.brotli.overrideAttrs {
        version = "1.2.1";
        src = pkgs.fetchFromGitHub {
          owner = "google";
          repo = "brotli";
          tag = "v1.2.1";
          hash = "sha256-llY72cYffDv0ugsH0p89xIPEbElV4L8u7U/Fe8hT3gI=";
        };
        # Both the decoder fix and Nixpkgs' platform fix are in this release.
        patches = [];
      };
  containerBrotli = pkgs:
    pkgs.runCommand "container-brotli-node2shell" {nativeBuildInputs = [pkgs.patchelf];} ''
      mkdir -p "$out"
      cp -L ${lib.getLib (patchedBrotli pkgs)}/lib/libbrotli*.so.1 "$out/"
      chmod u+w "$out/"*
      for library in "$out/"*; do
        patchelf --set-rpath /opt/forge-brotli "$library"
      done
    '';
  pyarrowVolumes = pkgs: let
    patched = pkgs.callPackage ../../packages/node2shell/pyarrow.nix {};
    sitePackages = "/app/.venv/lib/python3.12/site-packages";
  in [
    "${patched}/pyarrow:${sitePackages}/pyarrow:ro"
    "${patched}/pyarrow.libs:${sitePackages}/pyarrow.libs:ro"
    # Replace the image's distribution metadata together with its Python modules.
    "${patched}/pyarrow-26.0.1.dist-info:${sitePackages}/pyarrow-25.0.1.dist-info:ro"
  ];
  # The images bundle additional copies outside the host's Nix closure.
  pillowVolumes = pkgs: let
    patched = containerBrotli pkgs;
    pillow = "/app/.venv/lib/python3.12/site-packages/pillow.libs";
  in [
    "${patched}:/opt/forge-brotli:ro"
    "${patched}/libbrotlidec.so.1:${pillow}/libbrotlidec-7e5462ba.so.1.2.0:ro"
    "${patched}/libbrotlicommon.so.1:${pillow}/libbrotlicommon-53534446.so.1.2.0:ro"
  ];
  systemVolumes = pkgs: let
    patched = containerBrotli pkgs;
  in
    map (name: "${patched}/libbrotli${name}.so.1:/usr/lib/x86_64-linux-gnu/libbrotli${name}.so.1:ro") ["common" "dec" "enc"];
  # nixpkgs, the atlas/nook app pins and authentik's nixpkgs already ship Brotli 1.2.1.
  nomBrotli = inputs.nix-output-monitor.inputs.nixpkgs.legacyPackages.x86_64-linux.brotli;
in {
  # Temporary security fixes for copies outside the fixed pins. Remove the graft
  # once nix-output-monitor's nixpkgs ships Brotli 1.2.1, and the volumes once the
  # container images do.
  nixos.atlas = {pkgs, ...}: {
    virtualisation.oci-containers.containers.authentik-ldap-outpost.volumes =
      ["${containerBrotli pkgs}:/opt/forge-brotli:ro"] ++ systemVolumes pkgs;
  };
  nixos.nook = {
    config,
    pkgs,
    ...
  }: {
    assertions =
      map (container: {
        assertion = config.virtualisation.oci-containers.containers.${container.name}.image == container.image;
        message = "Recheck the bundled Brotli replacements before changing the ${container.name} image.";
      }) [
        {
          name = "cognee";
          image = "docker.io/cognee/cognee@sha256:84584eade25cd9526ef4fe8dd550be69fb974fb1083bde9e498da451fad0dfc6";
        }
        {
          name = "cognee-mcp";
          image = "docker.io/cognee/cognee-mcp@sha256:32ddfdf969dd6c910d36372af6b50a8de079d2f0880620691acebcda89c6ff30";
        }
      ];
    # An ABI-compatible graft avoids rebuilding nix-output-monitor's closure.
    system.replaceDependencies.replacements = [
      {
        oldDependency = lib.getLib nomBrotli;
        newDependency = lib.getLib (patchedBrotli pkgs);
      }
    ];
    virtualisation.oci-containers.containers = {
      cognee.volumes = pillowVolumes pkgs ++ systemVolumes pkgs ++ pyarrowVolumes pkgs;
      cognee-mcp.volumes = pillowVolumes pkgs;
    };
  };
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.node2shell = pkgs.runCommand "node2shell-regression" {nativeBuildInputs = [pkgs.python3 pkgs.binutils];} ''
        python3 ${../../packages/node2shell/test-decoder.py} \
          ${lib.getLib (patchedBrotli pkgs)}/lib/libbrotlidec.so.1 \
          ${lib.getLib (patchedBrotli pkgs)}/lib/libbrotlienc.so.1
        ${pkgs.nodejs_24}/bin/node ${../../packages/node2shell/test-node.cjs}
        ${pkgs.nodejs_22}/bin/node ${../../packages/node2shell/test-node.cjs}
        # Container bases use glibc 2.36: reject newer symbol requirements.
        for library in ${containerBrotli pkgs}/*; do
          readelf --version-info "$library" | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1 | \
            ${pkgs.gawk}/bin/awk -F '[_.]' '{ if ($2 > 2 || ($2 == 2 && $3 > 36)) exit 1 }'
        done
        touch "$out"
      '';
      packages.node2shell-brotli = patchedBrotli pkgs;
      packages.node2shell-container-brotli = containerBrotli pkgs;
      packages.node2shell-pyarrow = pkgs.callPackage ../../packages/node2shell/pyarrow.nix {};
    };
}
