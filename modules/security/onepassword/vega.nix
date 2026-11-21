{
  home.lisa-vega = {
    config,
    lib,
    ...
  }: {
    programs.git.settings.gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    home.sessionVariables.SSH_AUTH_SOCK = lib.mkDefault "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
}
