{config, ...}: let
  remotes = config.sshRemotes;
in {
  # Every host goes through the 1Password agent that onepassword/asterion.nix starts.
  home.lisa-asterion.programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings =
      remotes
      // {
        "*".IdentityAgent = "~/.1password/agent.sock";
        "codeberg.org" = {
          HostName = "codeberg.org";
          User = "git";
          IdentityFile = "~/.ssh/codeberg.pub";
          IdentitiesOnly = true;
        };
      };
  };
}
