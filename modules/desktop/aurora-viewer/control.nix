{config, ...}: {
  overlays.aurora-control = final: _prev: {
    aurora-control = final.callPackage ../../../packages/aurora-control/package.nix {};
  };
  perSystem = {pkgs, ...}: {
    packages.aurora-control = pkgs.aurora-control;
    checks.aurora-control = pkgs.aurora-control;
  };

  # The control bridge is a forge patch of the viewer (docs/aurora-viewer.md).
  # Normal launches stay unchanged; `aurora-viewer-control` starts the app
  # with the bridge, and agents reach it through `aurora-control-mcp`.
  home.aurora-control = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.forge.auroraControl;
    mcpServer = {
      command = "${cfg.package}/bin/aurora-control-mcp";
      args = ["--directory" cfg.directory];
    };
    launcher = pkgs.writeShellApplication {
      name = "aurora-viewer-control";
      runtimeInputs = [cfg.package];
      text = ''
        dir="''${AURORA_CONTROL_DIR:-${cfg.directory}}"
        if [ -e "$dir" ] || [ -L "$dir" ]; then
          status=0
          aurora-control --directory "$dir" --timeout 5 viewer_state </dev/null >/dev/null 2>&1 || status=$?
          if [ "$status" -ne 2 ]; then
            echo "aurora-viewer-control: a viewer with the control bridge already runs at $dir" >&2
            exit 1
          fi
          # A viewer that did not quit cleanly leaves its private directory.
          if [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ]; then
            rm -f "$dir/control.sock"
            rmdir "$dir"
          else
            echo "aurora-viewer-control: $dir exists and is not a stale control directory" >&2
            exit 1
          fi
        fi
        # LaunchServices starts the app without this shell's environment:
        # forward the AURORA_* variables (AURORA_DEMO=1 for the offline demo).
        forwarded=(--env "AURORA_CONTROL_DIR=$dir")
        for name in "''${!AURORA_@}"; do
          if [[ $name != AURORA_CONTROL_DIR ]]; then
            forwarded+=(--env "$name=''${!name}")
          fi
        done
        # -n: a new instance, since an Aurora already open would ignore --env.
        exec /usr/bin/open -n -a "${cfg.viewer}/Applications/Aurora Viewer.app" "''${forwarded[@]}" --args "$@"
      '';
    };
  in {
    options.forge.auroraControl = {
      package = lib.mkPackageOption pkgs "aurora-control" {};
      viewer = lib.mkPackageOption pkgs "aurora-viewer" {};
      directory = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Library/Caches/aurora-control";
        description = "The viewer's AURORA_CONTROL_DIR: absolute, short, created by the viewer.";
      };
    };

    config = {
      home.packages = [cfg.package launcher];
      # Sixteen tools Claude rarely needs: attached on request with
      # `claude --mcp-config ~/.claude/mcp-available/aurora.json`.
      home.file.".claude/mcp-available/aurora.json".text = builtins.toJSON {mcpServers.aurora = mcpServer;};
      programs.codex = {
        enableMcpIntegration = lib.mkDefault true;
        settings.mcp_servers.aurora =
          mcpServer
          // {
            startup_timeout_sec = 10;
            # the viewer answers within 30 s; a capture waits up to 15 s
            tool_timeout_sec = 60;
            omit_tools_from = ["direct"];
          };
      };
    };
  };
  home.lisa-vega.imports = [config.home.aurora-control];
}
