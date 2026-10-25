{inputs, ...}: {
  flake-file.inputs.steam-asahi = {
    url = "github:sm-idk/steam-asahi";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixos.asterion = {
    config,
    pkgs,
    ...
  }: {
    imports = [inputs.steam-asahi.nixosModules.default];
    programs.steam-asahi = {
      enable = true;
      package =
        (pkgs.steam-asahi.override {
          inherit (config.programs.steam-asahi) extraEnv memoryMiB;
        }).overrideAttrs (old: {
          buildCommand =
            old.buildCommand
            + ''
              # CEF's accelerated web UI renders solid magenta through muvm on M3.
              launcher="$out/bin/steam-asahi"
              target=$(readlink -f "$launcher")
              cp --remove-destination "$target" "$launcher"
              chmod u+w "$launcher"
              substituteInPlace "$launcher" \
                --replace-fail 'steam_args="-cef-force-occlusion' \
                  'steam_args="-cef-force-occlusion -cef-disable-gpu'
            '';
        });
    };
    hardware.steam-hardware.enable = true;
    users.users.lisa.extraGroups = ["kvm"];
  };
}
