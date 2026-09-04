{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      PermitEmptyPasswords = false;
      PermitUserEnvironment = false;
    };
  };
}
