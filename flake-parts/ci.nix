{
  config,
  lib,
  ...
}: let
  runners = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-15";
    x86_64-darwin = "macos-15-intel";
  };
  # Reading evaluated configurations can trigger platform-specific builds (IFD).
  # Use the same declarations as configurations.nix to discover native runners.
  configurations = output: suffix: declarations:
    map (name: {
      target = "${output}.${builtins.toJSON name}.${suffix}";
      runner = runners.${declarations.${name}.system};
    }) (builtins.attrNames declarations);
in {
  flake.ciMatrix.include =
    configurations "nixosConfigurations" "config.system.build.toplevel"
    (lib.filterAttrs (_: host: host.class == "nixos") config.forge.hosts)
    ++ configurations "darwinConfigurations" "system"
    (lib.filterAttrs (_: host: host.class == "darwin") config.forge.hosts)
    ++ configurations "homeConfigurations" "activationPackage" config.forge.homes
    ++ map (name: {
      target = "packages.aarch64-linux.${name}";
      runner = runners.aarch64-linux;
    }) ["asterion-installer" "asterion-tethered-installer"];
}
