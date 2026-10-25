{
  nixos.asterion-audio = {
    lib,
    pkgs,
    ...
  }: {
    # The installer disables this; enable upstream DSP and protection together.
    hardware.asahi.setupAsahiSound = lib.mkForce true;
    environment.systemPackages = [pkgs.alsa-utils];
  };
}
