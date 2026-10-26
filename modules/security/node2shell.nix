{
  inputs,
  lib,
  ...
}: let
  patchedBrotli = pkgs:
    pkgs.brotli.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          (pkgs.fetchurl {
            url = "https://github.com/google/brotli/commit/0ed4268a4401abcb4472096340477cf4af7d1a2b.patch?full_index=1";
            hash = "sha256-1vliUJAAIj3vcGKVgim9CEV+XgMuftDR2U+3kLBUsfw=";
          })
        ];
    });
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
  replacements = pkgs: sources:
    map (original: {
      oldDependency = lib.getLib original.brotli;
      newDependency = lib.getLib (patchedBrotli pkgs);
    })
    sources;
  pinnedNook = inputs.nixpkgs-nook-apps.legacyPackages.x86_64-linux;
  authentik = inputs.authentik-nix.inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  # Temporary ABI-compatible security grafts preserve pinned app/database versions
  # and avoid rebuilding the world. Remove after every source pin includes the fix.
  nixos.atlas = {pkgs, ...}: {
    system.replaceDependencies.replacements = replacements pkgs [pkgs authentik inputs.nixpkgs-atlas-apps.legacyPackages.x86_64-linux];
    virtualisation.oci-containers.containers.authentik-ldap-outpost.volumes =
      ["${containerBrotli pkgs}:/opt/forge-brotli:ro"] ++ systemVolumes pkgs;
  };
  nixos.nook = {
    config,
    pkgs,
    ...
  }: let
    runtimes = pkgs.dotnetCorePackages.buildDotnetSdk ../../packages/node2shell/dotnet-runtimes.nix;
    runtimeReplacements = lib.concatMap (source:
      map (name: {
        oldDependency = source.dotnetCorePackages.${name};
        newDependency = runtimes.${name}.overrideAttrs {pname = source.dotnetCorePackages.${name}.pname;};
      }) ["aspnetcore_8_0" "aspnetcore_10_0"])
    [pkgs pinnedNook];
  in {
    assertions =
      map (container: {
        assertion = config.virtualisation.oci-containers.containers.${container.name}.image == container.image;
        message = "Recheck the bundled Brotli replacements before changing the ${container.name} image.";
      }) [
        {
          name = "cognee";
          image = "docker.io/cognee/cognee@sha256:05ac5ca16f0308190e06771c35d9be0d666c313ad1deb587228ec26179f2336e";
        }
        {
          name = "cognee-mcp";
          image = "docker.io/cognee/cognee-mcp@sha256:240b49174b5dcf5906e8e5a6d46b24b947361866be93956032d7e88c0876bafa";
        }
      ];
    system.replaceDependencies.replacements =
      replacements pkgs [pkgs pinnedNook inputs.nix-output-monitor.inputs.nixpkgs.legacyPackages.x86_64-linux]
      ++ runtimeReplacements;
    virtualisation.oci-containers.containers = {
      cognee.volumes = pillowVolumes pkgs ++ systemVolumes pkgs ++ pyarrowVolumes pkgs;
      cognee-mcp.volumes = pillowVolumes pkgs ++ pyarrowVolumes pkgs;
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
        ${pkgs.replaceDependencies {
          drv = pkgs.nodejs_24;
          replacements = replacements pkgs [pkgs];
        }}/bin/node ${../../packages/node2shell/test-node.cjs}
        ${pkgs.nodejs_22}/bin/node ${../../packages/node2shell/test-node.cjs}
        # Container bases use glibc 2.36: reject newer symbol requirements.
        for library in ${containerBrotli pkgs}/*; do
          readelf --version-info "$library" | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1 | \
            ${pkgs.gawk}/bin/awk -F '[_.]' '{ if ($2 > 2 || ($2 == 2 && $3 > 36)) exit 1 }'
        done
        ${lib.concatMapStringsSep "\n" (name: let
          runtime = (pkgs.dotnetCorePackages.buildDotnetSdk ../../packages/node2shell/dotnet-runtimes.nix).${name};
          native = "${runtime}/share/dotnet/shared/Microsoft.NETCore.App/${runtime.version}/libSystem.IO.Compression.Native.so";
        in ''
          python3 ${../../packages/node2shell/test-decoder.py} ${native} ${native}
          ${runtime}/bin/dotnet --list-runtimes | grep 'Microsoft.NETCore.App ${runtime.version}'
        '') ["aspnetcore_8_0" "aspnetcore_10_0"]}
        touch "$out"
      '';
      packages.node2shell-brotli = patchedBrotli pkgs;
      packages.node2shell-container-brotli = containerBrotli pkgs;
      packages.node2shell-pyarrow = pkgs.callPackage ../../packages/node2shell/pyarrow.nix {};
      packages.node2shell-dotnet8 = (pkgs.dotnetCorePackages.buildDotnetSdk ../../packages/node2shell/dotnet-runtimes.nix).aspnetcore_8_0;
      packages.node2shell-dotnet10 = (pkgs.dotnetCorePackages.buildDotnetSdk ../../packages/node2shell/dotnet-runtimes.nix).aspnetcore_10_0;
    };
}
