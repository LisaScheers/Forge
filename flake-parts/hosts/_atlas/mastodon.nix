{
  services.mastodon = {
    enable = false;
    localDomain = "mastodon.bylisa.dev";
    smtp.fromAddress = "mastodon@scheers.tech";
    streamingProcesses = 2;
  };
}
