{
  nixos.asterion = {
    services.gnome.gcr-ssh-agent.enable = false;
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = ["lisa"];
    };
    environment.etc = {
      "1password/custom_allowed_browsers" = {
        mode = "0755";
        text = ''
          helium
        '';
      };
      "chromium/policies/managed/asterion-1password.json".text = builtins.toJSON {
        ExtensionInstallForcelist = [
          # Helium routes its default update URL through its consent-aware proxy.
          "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
        ];
      };
    };
  };

  home.lisa-asterion = {
    config,
    lib,
    pkgs,
    osConfig ? null,
    ...
  }: let
    gui =
      if osConfig != null
      then osConfig.programs._1password-gui.package
      else pkgs._1password-gui;
  in {
    home.file = builtins.listToAttrs (map (key: {
      name = ".ssh/${key}";
      value.source = ./ssh/vega/public-keys/${key};
    }) (builtins.filter (key: builtins.match ".*\\.pub" key != null) (builtins.attrNames (builtins.readDir ./ssh/vega/public-keys))));

    xdg.configFile."net.imput.helium/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
      name = "com.1password.1password";
      description = "1Password browser integration";
      path = "/run/wrappers/bin/1Password-BrowserSupport";
      type = "stdio";
      allowed_origins = ["chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"];
    };

    systemd.user.services.onepassword = {
      Unit = {
        Description = "1Password desktop integration";
        After = ["niri.service"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${lib.getExe gui} --silent";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*".IdentityAgent = "~/.1password/agent.sock";
        "codeberg.org" = {
          HostName = "codeberg.org";
          User = "git";
          IdentityFile = "~/.ssh/codeberg.pub";
          IdentitiesOnly = true;
        };
        "mail" = {
          HostName = "100.121.88.128";
          User = "root";
          IdentityFile = "~/.ssh/root@mail.pub";
          IdentitiesOnly = true;
        };
        "atlas" = {
          HostName = "100.87.26.75";
          User = "lisa";
          IdentityFile = "~/.ssh/lisa@atlas.pub";
          IdentitiesOnly = true;
        };
        "nook" = {
          HostName = "100.106.233.104";
          User = "lisa";
          IdentityFile = "~/.ssh/home-server.pub";
          IdentitiesOnly = true;
        };
      };
    };
    programs.git.settings = {
      gpg = {
        format = "ssh";
        ssh = {
          allowedSignersFile = "${config.xdg.configHome}/git/allowed_signers";
          program = lib.getExe' gui "op-ssh-sign";
        };
      };
      commit.gpgsign = true;
    };
    programs._1password-shell-plugins = {
      enable = true;
      plugins = with pkgs; [awscli2 cachix];
      package = pkgs._1password-cli;
    };
  };
}
