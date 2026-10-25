{
  nixos.asterion = {
    services.upower = {
      enable = true;
      # Native display/GPU resume is unqualified; avoid sleep at critical charge.
      criticalPowerAction = "PowerOff";
    };
  };
}
