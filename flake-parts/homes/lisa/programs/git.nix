{
  forge.modules.homeManager.lisa-shell = {
    lib,
    pkgs,
    ...
  }: let
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHM77QyWYhDIEUzvyv57MoXgtO8zokNcIM0q442WUX61";
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
        credential."https://git.bylisa.dev" = {
          username = "Lisa";
          helper = [
            ""
            (
              if pkgs.stdenv.hostPlatform.isDarwin
              then "osxkeychain"
              else "cache --timeout=21600"
            )
            (lib.getExe pkgs.git-credential-oauth)
          ];
          # Share Forgejo's built-in API client with forgejo-api.
          oauthClientId = pkgs.forgejo-api.oauthClientId;
          oauthAuthURL = "/login/oauth/authorize";
          oauthTokenURL = "/login/oauth/access_token";
          # Creating a repository uses /user/repos, so repository scope alone
          # cannot cover the API workflow. Share the grant with forgejo-api.
          oauthScopes = pkgs.forgejo-api.oauthScopes;
        };
      };
    };

    xdg.configFile."git/allowed_signers".text = ''
      lisa@scheers.tech ${signingKey}
    '';

    home.packages = with pkgs; [
      gh
      forgejo-api
    ];
  };
}
