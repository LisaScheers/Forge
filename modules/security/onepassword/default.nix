{
  config,
  inputs,
  ...
}: let
  inherit (config.home) onepassword;
in {
  flake-file.inputs.onepassword-shell-plugins = {
    url = "github:1Password/shell-plugins";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  home.lisa.imports = [inputs.onepassword-shell-plugins.hmModules.default];
  # Shell plugins and SSH commit signing; each workstation names its signer.
  home.onepassword = {
    config,
    pkgs,
    ...
  }: {
    programs._1password-shell-plugins = {
      enable = true;
      plugins = with pkgs; [awscli2 cachix];
      package = pkgs._1password-cli;
    };
    programs.git.settings = {
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
      };
      commit.gpgsign = true;
    };
  };
  home.lisa-vega = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [onepassword];
    programs.git.settings.gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    home.sessionVariables = {
      SSH_AUTH_SOCK = lib.mkDefault "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };
    home.packages = [
      pkgs.gh
      #ghWith1Password disables due to anoying popups when running gh commands that require 1password auth, so we use the normal gh package instead
    ];
  };
}
