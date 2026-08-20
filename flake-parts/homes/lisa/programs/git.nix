{...}: let
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
    };
  };

  xdg.configFile."git/allowed_signers".text = ''
    lisa@scheers.tech ${signingKey}
  '';
}
