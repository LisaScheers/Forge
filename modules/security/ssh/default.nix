{
  config,
  lib,
  ...
}: let
  # One SSH host block per network entry that declares a login.
  remotes = lib.mapAttrs (_: host: {
    HostName = host.tailscale;
    User = host.ssh.user;
    IdentityFile = host.ssh.identityFile;
    IdentitiesOnly = true;
  }) (lib.filterAttrs (_: host: host.ssh != null) config.network);
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
            IdentityAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };

          "localhost" = {
            User = "lisa";
            IdentityFile = "~/.ssh/home-server.pub";
            IdentitiesOnly = true;
            IdentityAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
    };
  };
}
