{
  home.lisa-cli = {
    lib,
    pkgs,
    ...
  }: let
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHM77QyWYhDIEUzvyv57MoXgtO8zokNcIM0q442WUX61";
    fjCredentialHelper = pkgs.writeShellApplication {
      name = "git-credential-fj";
      runtimeInputs = [pkgs.forgejo-cli pkgs.jq];
      text = builtins.readFile ./git-credential-fj.sh;
    };
  in {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Lisa Scheers";
          email = "lisa@scheers.tech";
          signingkey = signingKey;
        };
        init.defaultBranch = "main";
        credential."https://github.com".helper = ["" "!${lib.getExe pkgs.gh} auth git-credential"];
        credential."https://gist.github.com".helper = ["" "!${lib.getExe pkgs.gh} auth git-credential"];
        credential."https://git.bylisa.dev" = {
          username = "Lisa";
          helper = [
            ""
            (lib.getExe fjCredentialHelper)
          ];
        };
      };
    };

    xdg.configFile."git/allowed_signers".text = ''
      lisa@scheers.tech ${signingKey}
    '';

    home.packages = with pkgs; [
      gh
      forgejo-cli
      forgejo-api
    ];
  };
}
