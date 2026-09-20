{config, ...}: let
  flake = config.flake;
  runners = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-15";
    x86_64-darwin = "macos-15-intel";
  };
  configurations = output: suffix:
    map (name: {
      target = "${output}.${builtins.toJSON name}.${suffix}";
      runner = runners.${flake.${output}.${name}.pkgs.stdenv.hostPlatform.system};
    }) (builtins.attrNames flake.${output});
in {
  flake.ciMatrix.include =
    configurations "nixosConfigurations" "config.system.build.toplevel"
    ++ configurations "darwinConfigurations" "system"
    ++ configurations "homeConfigurations" "activationPackage"
    ++ map (name: {
      target = "packages.aarch64-linux.${name}";
      runner = runners.aarch64-linux;
    }) ["asterion-installer" "asterion-tethered-installer"];
}
