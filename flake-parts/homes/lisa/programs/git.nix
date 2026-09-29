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
          # Forgejo's built-in public client uses browser sign-in via Authentik.
          oauthClientId = "a4792ccc-144e-407e-86c9-5e7d8d9c3269";
          oauthAuthURL = "/login/oauth/authorize";
          oauthTokenURL = "/login/oauth/access_token";
          oauthScopes = "write:repository";
        };
      };
    };

    xdg.configFile."git/allowed_signers".text = ''
      lisa@scheers.tech ${signingKey}
    '';

    home.packages = with pkgs; [
      gh
    ];
  };
}
