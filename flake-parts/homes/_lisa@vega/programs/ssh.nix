{config, ...}: let
  homeDirectory = config.home.homeDirectory;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = ["~/.orbstack/ssh/config"];
    settings = {
      "codeberg.org" = {
        HostName = "codeberg.org";
        User = "git";
        IdentityFile = "~/.ssh/codeberg.pub";
        IdentitiesOnly = true;
        IdentityAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      };

      "mail" = {
        HostName = "100.121.88.128";
        User = "root";
        Port = 22;
        IdentityFile = "~/.ssh/root@mail.pub";
        IdentitiesOnly = true;
        IdentityAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      };

      "atlas" = {
        HostName = "100.87.26.75";
        User = "lisa";
        IdentityFile = "~/.ssh/lisa@atlas.pub";
        IdentitiesOnly = true;
        IdentityAgent = "\"${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      };

      "nook" = {
        HostName = "100.106.233.104";
        User = "lisa";
        IdentityFile = "~/.ssh/home-server.pub";
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
}
