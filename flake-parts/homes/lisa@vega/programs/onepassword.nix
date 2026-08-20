{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  ssh-sock =
    if isDarwin
    then "~/.1password/agent.sock"
    else if isLinux
    then "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "";
  ssh-sign-program =
    if isDarwin
    then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else lib.getExe' pkgs._1password-gui "op-ssh-sign";
in {
  programs._1password-shell-plugins = {
    enable = true;
    plugins = with pkgs; [awscli2 cachix];
    package = pkgs._1password-cli;
  };

  programs.git.settings = {
    gpg = {
      format = "ssh";
      ssh = {
        allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
        program = ssh-sign-program;
      };
    };
    commit.gpgsign = true;
  };

  home.sessionVariables = {
    SSH_AUTH_SOCK = lib.mkDefault ssh-sock;
  };
  home.packages = [
    pkgs.gh
    #ghWith1Password disables due to anoying popups when running gh commands that require 1password auth, so we use the normal gh package instead
  ];
}
