{
  nixos.asterion = {pkgs, ...}: let
    controller = pkgs.writeShellApplication {
      name = "asterion-fan-control";
      runtimeInputs = [pkgs.python3];
      text = ''
        exec python3 -B ${../../../scripts/asterion-fan-control.py} "$@"
      '';
    };
  in {
    boot.kernelParams = ["macsmc_hwmon.fan_control=1"];
    environment.systemPackages = [controller];
    systemd.services.asterion-fan-control = {
      description = "Control both fans from Asterion's hottest SoC temperature";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service"];
      # Changing the parameter after probing does not recreate writable targets.
      unitConfig.ConditionKernelCommandLine = "macsmc_hwmon.fan_control=1";
      serviceConfig = {
        ExecStart = "${controller}/bin/asterion-fan-control --curve 40:30,55:50,65:75,75:100";
        # Also restore firmware control after a crash or forced termination.
        ExecStopPost = "${controller}/bin/asterion-fan-control --restore";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 10;
      };
    };
  };
  perSystem = {pkgs, ...}: {
    checks.asterion-fan-control =
      pkgs.runCommand "asterion-fan-control-tests" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        ASTERION_FAN_CONTROL=${../../../scripts/asterion-fan-control.py} \
          python3 -B ${../../../scripts/test_asterion_fan_control.py}
        touch "$out"
      '';
  };
}
