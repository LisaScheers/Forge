{inputs, ...}: {
  flake.lib.nixdSettings = pkgs:
    import ../../packages/nixd/settings.nix {
      inherit (pkgs) lib;
      inherit pkgs;
      forge = inputs.self;
    };

  perSystem = {pkgs, ...}: {
    packages.nixd-config =
      (pkgs.formats.json {}).generate "nixd-config.json"
      (inputs.self.lib.nixdSettings pkgs);
  };

  home.lisa-cli = {pkgs, ...}: {
    home.packages = [pkgs.nixd];
    xdg.configFile."nixd/config.json".source =
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixd-config;
  };
}
