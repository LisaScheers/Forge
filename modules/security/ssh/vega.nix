{
  config,
  lib,
  ...
}: let
  remotes = config.sshRemotes;
in {
  home.lisa-vega = {config, ...}: let
    homeDirectory = config.home.homeDirectory;
    onePasswordAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
  in {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = ["~/.orbstack/ssh/config"];
      settings =
        lib.mapAttrs (_: block: block // {IdentityAgent = onePasswordAgent;}) remotes
        // {
          "codeberg.org" = {
            HostName = "codeberg.org";
            User = "git";
            IdentityFile = "~/.ssh/codeberg.pub";
            IdentitiesOnly = true;
            IdentityAgent = onePasswordAgent;
          };

          "localhost" = {
            User = "lisa";
            IdentityFile = "~/.ssh/home-server.pub";
            IdentitiesOnly = true;
            IdentityAgent = onePasswordAgent;
          };
        };
    };
  };
}
