{inputs, ...}: {
  flake-file.inputs.onepassword-shell-plugins = {
    url = "github:1Password/shell-plugins";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # Shell plugins and SSH commit signing for a workstation home. The importer
  # sets programs.git.settings.gpg.ssh.program to its 1Password signer, and the
  # allowed-signers file comes from modules/shell/git.nix.
  home.onepassword = {
    config,
    pkgs,
    ...
  }: {
    imports = [inputs.onepassword-shell-plugins.hmModules.default];
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
}
