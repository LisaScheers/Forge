{
  home.lisa-asterion = {pkgs, ...}: {
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird;
      profiles.lisa = {
        isDefault = true;
        settings = {
          "mail.shell.checkDefaultClient" = false;
          "mailnews.start_page.enabled" = false;
        };
      };
    };

    accounts.email.accounts.scheers = {
      primary = true;
      address = "lisa@scheers.tech";
      realName = "Lisa Scheers";
      userName = "lisa@scheers.tech";
      # The provider advertises password authentication inside implicit TLS.
      # Thunderbird enrolls the password locally rather than through Nix.
      imap = {
        host = "m.scheers.tech";
        port = 993;
        authentication = "plain";
        tls.enable = true;
      };
      smtp = {
        host = "m.scheers.tech";
        port = 465;
        authentication = "plain";
        tls.enable = true;
      };
      thunderbird = {
        enable = true;
        profiles = ["lisa"];
      };
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/mailto" = ["thunderbird.desktop"];
      "message/rfc822" = ["thunderbird.desktop"];
      "text/calendar" = ["thunderbird.desktop"];
      "x-scheme-handler/webcal" = ["thunderbird.desktop"];
      "x-scheme-handler/webcals" = ["thunderbird.desktop"];
    };
  };
}
