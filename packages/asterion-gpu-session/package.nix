{
  lib,
  pkgs,
  mesa,
  renderDevice ? "/dev/dri/renderD128",
  installed ? false,
}: let
  fontConfig = pkgs.makeFontsConf {fontDirectories = [pkgs.dejavu_fonts];};
  fontEnvironment =
    if installed
    then ''unset FONTCONFIG_FILE''
    else ''export FONTCONFIG_FILE=${fontConfig}'';
  mesaEnvironment = ''
    export __EGL_VENDOR_LIBRARY_FILENAMES=${mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export LIBGL_DRIVERS_PATH=${mesa}/lib/dri
    export GBM_BACKENDS_PATH=${mesa}/lib/gbm
    export GBM_BACKEND=dri
    icds=(${mesa}/share/vulkan/icd.d/asahi_icd*.json)
    [[ ''${#icds[@]} == 1 && -f ''${icds[0]} ]]
    export VK_DRIVER_FILES="''${icds[0]}"
    unset LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER MESA_LOADER_DRIVER_OVERRIDE
  '';
  footConfigSource = pkgs.writeText "asterion-gpu-foot.ini" ''
    [main]
    font=DejaVu Sans Mono:size=11
    pad=10x10
    [colors-dark]
    background=000000
    foreground=ffffff
    [colors-light]
    background=000000
    foreground=ffffff
  '';
  footConfig = pkgs.runCommand "asterion-gpu-foot-config" {nativeBuildInputs = [pkgs.foot];} ''
    foot --check-config --config ${footConfigSource}
    cp ${footConfigSource} "$out"
  '';
  terminal = pkgs.writeShellApplication {
    name = "asterion-gpu-terminal";
    text = ''
      cd "$HOME"
      ${
        if installed
        then ''exec ${lib.getExe pkgs.ghostty} "$@"''
        else ''exec ${lib.getExe pkgs.foot} --config ${footConfig} "$@"''
      }
    '';
  };
  terminalDesktop = pkgs.makeDesktopItem {
    name = "asterion-terminal";
    desktopName = "Terminal";
    exec = lib.getExe terminal;
    icon =
      if installed
      then "com.mitchellh.ghostty"
      else "foot";
    categories = ["System" "TerminalEmulator"];
  };
  desktopDataDirs = "${terminalDesktop}/share:${pkgs.foot}/share:${pkgs.fuzzel}/share:${pkgs.noctalia}/share:${pkgs.vanilla-dmz}/share";
  fuzzelConfig = pkgs.writeText "asterion-gpu-fuzzel.ini" ''
    [main]
    terminal=${lib.getExe terminal}
    font=DejaVu Sans:size=11
    width=40
    lines=10
    [colors]
    background=000000ff
    text=ffffffff
    match=ffffffff
    selection=222222ff
    selection-text=ffffffff
    selection-match=ffffffff
    border=ffffffff
    [border]
    width=1
    radius=0
  '';
  launcher = pkgs.writeShellApplication {
    name = "asterion-gpu-launcher";
    text = ''
      exec ${lib.getExe pkgs.fuzzel} --config ${fuzzelConfig} "$@"
    '';
  };
  noctaliaConfigSource =
    if installed
    then
      pkgs.writeText "asterion-noctalia.toml" ((lib.replaceStrings [''end = ["tray"''] [''end = ["volume", "tray"''] (builtins.readFile ./noctalia.toml))
        + ''

          [[shell.session.actions]]
          action = "lock"
          enabled = false

          [[shell.session.actions]]
          action = "lock_and_suspend"
          enabled = false

          [[shell.session.actions]]
          action = "suspend"
          enabled = false
        '')
    else ./noctalia.toml;
  noctaliaConfig = pkgs.runCommand "asterion-gpu-noctalia-config" {nativeBuildInputs = [pkgs.noctalia];} ''
    mkdir -p "$out/noctalia/palettes"
    cp ${noctaliaConfigSource} "$out/noctalia/config.toml"
    cp ${./palette.json} "$out/noctalia/palettes/Asterion.json"
    validation=$(noctalia config validate "$out/noctalia" 2>&1)
    echo "$validation"
    case "$validation" in *WARN*) exit 1;; esac
  '';
  noctalia = pkgs.writeShellApplication {
    name = "asterion-gpu-noctalia";
    runtimeInputs = [pkgs.coreutils pkgs.niri pkgs.xwayland-satellite];
    text = ''
      ${fontEnvironment}
      export XDG_CURRENT_DESKTOP=niri
      export XDG_DATA_DIRS=${desktopDataDirs}:''${XDG_DATA_DIRS:-/run/current-system/sw/share}
      export XCURSOR_PATH=${pkgs.vanilla-dmz}/share/icons
      export XCURSOR_THEME=DMZ-White
      export XCURSOR_SIZE=24
      export NOCTALIA_CONFIG_HOME=${noctaliaConfig}
      export NOCTALIA_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}/asterion-gpu-session"
      ${mesaEnvironment}
      exec ${lib.getExe pkgs.noctalia} "$@"
    '';
  };
  keyboardBacklight = pkgs.writeShellApplication {
    name = "asterion-keyboard-backlight";
    runtimeInputs = [pkgs.systemd pkgs.jq];
    text = ''
      action=''${1:-}
      case "$action" in
        up|down|toggle) ;;
        *) echo 'Usage: asterion-keyboard-backlight up|down|toggle' >&2; exit 2 ;;
      esac
      service=org.freedesktop.UPower
      interface=org.freedesktop.UPower.KbdBacklight
      devices=$(busctl --system --json=short call "$service" /org/freedesktop/UPower \
        "$service" EnumerateKbdBacklights | jq -r '.data[0][]')
      test -n "$devices"
      while IFS= read -r device; do
        current=$(busctl --system --json=short call "$service" "$device" "$interface" GetBrightness | jq '.data[0]')
        maximum=$(busctl --system --json=short call "$service" "$device" "$interface" GetMaxBrightness | jq '.data[0]')
        (( maximum > 0 ))
        step=$(( (maximum + 9) / 10 ))
        case "$action" in
          up) value=$(( current + step )) ;;
          down) value=$(( current - step )) ;;
          toggle)
            if (( current > 0 )); then value=0; else value=$(( maximum * 30 / 100 )); fi
            ;;
        esac
        if (( value < 0 )); then value=0; fi
        if (( value > maximum )); then value=$maximum; fi
        busctl --system call "$service" "$device" "$interface" SetBrightness i "$value" >/dev/null
        ${lib.getExe noctalia} msg keyboard-backlight-osd "$(( value * 100 / maximum ))" >/dev/null || true
      done <<< "$devices"
    '';
  };
  installedBindings = lib.optionalString installed ''
    XF86AudioRaiseVolume allow-when-locked=true { spawn "${lib.getExe' pkgs.wireplumber "wpctl"}" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "${lib.getExe' pkgs.wireplumber "wpctl"}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute allow-when-locked=true { spawn "${lib.getExe' pkgs.wireplumber "wpctl"}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioMicMute allow-when-locked=true { spawn "${lib.getExe' pkgs.wireplumber "wpctl"}" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
    XF86MonBrightnessUp { spawn "${lib.getExe noctalia}" "msg" "brightness-up"; }
    XF86MonBrightnessDown { spawn "${lib.getExe noctalia}" "msg" "brightness-down"; }
    XF86KbdBrightnessUp allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "up"; }
    XF86KbdBrightnessDown allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "down"; }
    XF86KbdLightOnOff allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "toggle"; }
    Mod+XF86MonBrightnessUp allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "up"; }
    Mod+XF86MonBrightnessDown allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "down"; }
    Mod+Shift+K allow-when-locked=true { spawn "${lib.getExe keyboardBacklight}" "toggle"; }
  '';
  configTemplate = pkgs.writeText "config.kdl" (lib.replaceStrings ["@installedBindings@"] [installedBindings] (builtins.readFile ./config.kdl));
  configSource = pkgs.replaceVars configTemplate ({
      inherit renderDevice;
      terminal = lib.getExe terminal;
      launcher = lib.getExe launcher;
      noctalia = lib.getExe noctalia;
      terminalStartup = lib.optionalString (!installed) ''spawn-at-startup "${lib.getExe terminal}"'';
    }
    // lib.optionalAttrs installed {
      DEFAULT_AUDIO_SINK = null;
      DEFAULT_AUDIO_SOURCE = null;
    });
  config =
    pkgs.runCommand "asterion-gpu-niri-config" {
      nativeBuildInputs = [pkgs.niri];
    } ''
      niri validate --config ${configSource}
      cp ${configSource} "$out"
    '';
  session = pkgs.writeShellApplication {
    name = "asterion-gpu-session";
    runtimeInputs =
      [pkgs.coreutils pkgs.niri pkgs.foot pkgs.fuzzel pkgs.xwayland-satellite]
      ++ lib.optionals installed [pkgs.systemd pkgs.dbus pkgs.gnugrep pkgs.procps];
    text = ''
      [[ $(id -u) != 0 ]] || { echo 'Run the desktop as a regular user.' >&2; exit 1; }
      : "''${XDG_RUNTIME_DIR:?Start through a local PAM/logind session}"
      test -d "$XDG_RUNTIME_DIR"
      test -c ${lib.escapeShellArg renderDevice}
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=niri
      ${fontEnvironment}
      export XDG_DATA_DIRS=${desktopDataDirs}:''${XDG_DATA_DIRS:-/run/current-system/sw/share}
      export XCURSOR_PATH=${pkgs.vanilla-dmz}/share/icons
      export XCURSOR_THEME=DMZ-White
      export XCURSOR_SIZE=24
      ${mesaEnvironment}
      unset DISPLAY WAYLAND_DISPLAY
      mkdir -p "$HOME/Pictures/Screenshots"
      cd "$HOME"
      ${
        if installed
        then ''
          export NIRI_CONFIG="$HOME/.config/niri/config.kdl"
          export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
          exec ${lib.getExe' pkgs.niri "niri-session"} -l
        ''
        else ''
          exec ${lib.getExe' pkgs.dbus "dbus-run-session"} -- ${lib.getExe pkgs.niri} --session --config ${config}
        ''
      }
    '';
  };
  desktopSession = pkgs.writeTextDir "share/wayland-sessions/asterion.desktop" ''
    [Desktop Entry]
    Name=Asterion
    Exec=${lib.getExe session}
    Type=Application
    DesktopNames=niri
  '';
in
  pkgs.symlinkJoin {
    name = "asterion-gpu-session";
    paths = [session terminal terminalDesktop launcher noctalia pkgs.niri pkgs.foot pkgs.fuzzel pkgs.noctalia pkgs.xwayland-satellite] ++ lib.optionals installed [desktopSession keyboardBacklight];
    passthru = {
      inherit config noctaliaConfig footConfig mesaEnvironment;
      providedSessions = lib.optional installed "asterion";
    };
    meta.mainProgram = "asterion-gpu-session";
  }
