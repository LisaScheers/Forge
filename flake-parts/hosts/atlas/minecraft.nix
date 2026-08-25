{
  pkgs,
  config,
  ...
}: let
  atm10Root = "/var/minecraft/atm10-8.0";
  atm11Root = "/var/minecraft/atm11-0.2.0";
  allTheMonsRoot = "/var/minecraft/allthemons-1.0.0-rc.6";
  minecraftJvmArgs = pkgs.writeText "minecraft-user_jvm_args.txt" ''
    -Xms8G
    -Xmx12G
    -XX:+UseG1GC
    -XX:+ParallelRefProcEnabled
    -XX:MaxGCPauseMillis=200
    -XX:+UnlockExperimentalVMOptions
    -XX:+DisableExplicitGC
    -XX:+AlwaysPreTouch
    -XX:G1NewSizePercent=30
    -XX:G1MaxNewSizePercent=40
    -XX:G1HeapRegionSize=8M
    -XX:G1ReservePercent=20
    -XX:G1HeapWastePercent=5
    -XX:G1MixedGCCountTarget=4
    -XX:InitiatingHeapOccupancyPercent=15
    -XX:G1MixedGCLiveThresholdPercent=90
    -XX:G1RSetUpdatingPauseTimePercent=5
    -XX:SurvivorRatio=32
    -XX:+PerfDisableSharedMem
    -XX:MaxTenuringThreshold=1
    -XX:+UseStringDeduplication
  '';
  minecraftOps = pkgs.writeText "minecraft-ops.json" (builtins.toJSON [
    {
      uuid = "ff7a4b5b-2535-4062-9ae5-118ab095864d";
      name = "Lisa_S000";
      level = 4;
      bypassesPlayerLimit = false;
    }
    {
      uuid = "e6c1ac04-512a-4a7e-b7f3-a0e23a808e8a";
      name = "eliasbe";
      level = 4;
      bypassesPlayerLimit = false;
    }
  ]);
  bluemapJar = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/swbUV1cr/versions/8iJcPOHJ/bluemap-5.7-neoforge.jar";
    sha256 = "0zaix791001kcpxlwa2dq4nx44618w7jiwjfqblxbl46369c6yl2";
  };
  chunkyJar = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/fALzjamp/versions/LuFhm4eU/Chunky-NeoForge-1.4.23.jar";
    sha256 = "0x6j5bws68y1ry25lc22h6r28i83lpfhph2j9wvjqvzmy5f26byp";
  };
  bluemapCoreConfig = pkgs.writeText "bluemap-core.conf" ''
    accept-download: true
    data: "bluemap"
    render-thread-count: 1
    scan-for-mod-resources: true
    metrics: true
  '';
  bluemapWebappConfig = pkgs.writeText "bluemap-webapp.conf" ''
    enabled: true
    webroot: "bluemap/web"
    update-settings-file: true
  '';
  bluemapWebserverConfig = pkgs.writeText "bluemap-webserver.conf" ''
    enabled: false
    webroot: "bluemap/web"
  '';
  bluemapPluginConfig = pkgs.writeText "bluemap-plugin.conf" ''
    live-player-markers: false
    player-render-limit: 1
    full-update-interval: 1440
  '';
in {
  systemd.services.atm-10-tts = {
    enable = false;
    wantedBy = ["multi-user.target"];
    path = with pkgs; [jdk21_headless];
    script = ''
      cd /var/minecraft/atm-10-tts
      ./run.sh
    '';
    # onFailure = "restart";
  };

  networking.firewall.allowedTCPPorts = [
    25565
    # rcon
  ];
  # rcon only allow from 84.198.125.249

  systemd.services.cutie-craft = {
    enable = false;
    wantedBy = ["multi-user.target"];
    path = with pkgs; [jdk21_headless];
    script = ''
      cd /var/minecraft/cutie-craft
      ./run.sh
    '';
    # onFailure = "restart";
  };

  systemd.services.cus2 = {
    enable = false;
    wantedBy = ["multi-user.target"];
    path = with pkgs; [jdk21_headless gawk wget];
    script = ''
      cd /var/minecraft/cus2
      ./start.sh
    '';
    # onFailure = "restart";
  };

  systemd.services.atm10-6-6.enable = false;

  systemd.services.atm10-8-0 = {
    enable = true;
    description = "All The Mods 10 8.0 Minecraft server";
    wantedBy = ["multi-user.target"];
    unitConfig.Conflicts = [
      "atm-10-tts.service"
      "atm10-6-6.service"
      "atm11-0-2-0.service"
      "cutie-craft.service"
      "cus2.service"
    ];
    path = with pkgs; [
      coreutils
      curl
      gawk
      jdk21_headless
      wget
    ];
    environment = {
      ATM10_JAVA = "${pkgs.jdk21_headless}/bin/java";
      ATM10_RESTART = "false";
    };
    preStart = ''
      if [ ! -f ${atm10Root}/startserver.sh ]; then
        echo "Missing ${atm10Root}/startserver.sh. Extract ServerFiles-8.0.zip into ${atm10Root} before starting this service."
        exit 1
      fi

      install -m 0644 ${minecraftJvmArgs} ${atm10Root}/user_jvm_args.txt
      install -m 0644 ${minecraftOps} ${atm10Root}/ops.json
      printf 'eula=true\n' > ${atm10Root}/eula.txt
      chmod +x ${atm10Root}/startserver.sh

      touch ${atm10Root}/server.properties
      set_property() {
        key="$1"
        value="$2"
        properties=${atm10Root}/server.properties
        if grep -q "^$key=" ${atm10Root}/server.properties; then
          awk -v key="$key" -v value="$value" '
            $0 ~ "^" key "=" {
              print key "=" value
              next
            }
            { print }
          ' "$properties" > "$properties.tmp"
          mv "$properties.tmp" "$properties"
        else
          printf '%s=%s\n' "$key" "$value" >> ${atm10Root}/server.properties
        fi
      }

      set_property allow-flight true
      set_property motd "All the Mods 10"
      set_property max-tick-time 180000
      set_property simulation-distance 5
      set_property view-distance 12
      set_property online-mode true
      if [ -f /root/allthemons-rcon.password ]; then
        set_property enable-rcon true
        set_property rcon.port 25575
        set_property rcon.password "$(cat /root/allthemons-rcon.password)"
      fi

      install -D -m 0644 ${bluemapJar} ${atm10Root}/mods/bluemap-5.7-neoforge.jar
      install -D -m 0644 ${bluemapCoreConfig} ${atm10Root}/config/bluemap/core.conf
      install -D -m 0644 ${bluemapWebappConfig} ${atm10Root}/config/bluemap/webapp.conf
      install -D -m 0644 ${bluemapWebserverConfig} ${atm10Root}/config/bluemap/webserver.conf
      install -D -m 0644 ${bluemapPluginConfig} ${atm10Root}/config/bluemap/plugin.conf
    '';
    script = ''
      cd ${atm10Root}
      exec ./startserver.sh
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = "30s";
      KillSignal = "SIGINT";
      TimeoutStopSec = "120s";
      MemoryHigh = "14G";
      MemoryMax = "16G";
    };
  };

  systemd.services.atm11-0-2-0 = {
    enable = false;
    description = "All The Mods 11 0.2.0 Minecraft server";
    wantedBy = ["multi-user.target"];
    unitConfig.Conflicts = [
      "atm-10-tts.service"
      "atm10-6-6.service"
      "atm10-8-0.service"
      "allthemons-1-0-0-rc-6.service"
      "cutie-craft.service"
      "cus2.service"
    ];
    path = with pkgs; [
      coreutils
      curl
      gawk
      jdk25_headless
      wget
    ];
    environment = {
      ATM11_JAVA = "${pkgs.jdk25_headless}/bin/java";
      ATM11_RESTART = "false";
    };
    preStart = ''
      if [ ! -f ${atm11Root}/startserver.sh ]; then
        echo "Missing ${atm11Root}/startserver.sh. Extract ServerFiles-0.2.0.zip into ${atm11Root} before starting this service."
        exit 1
      fi

      install -m 0644 ${minecraftJvmArgs} ${atm11Root}/user_jvm_args.txt
      install -m 0644 ${minecraftOps} ${atm11Root}/ops.json
      printf 'eula=true\n' > ${atm11Root}/eula.txt
      chmod +x ${atm11Root}/startserver.sh

      touch ${atm11Root}/server.properties
      set_property() {
        key="$1"
        value="$2"
        properties=${atm11Root}/server.properties
        if grep -q "^$key=" ${atm11Root}/server.properties; then
          awk -v key="$key" -v value="$value" '
            $0 ~ "^" key "=" {
              print key "=" value
              next
            }
            { print }
          ' "$properties" > "$properties.tmp"
          mv "$properties.tmp" "$properties"
        else
          printf '%s=%s\n' "$key" "$value" >> ${atm11Root}/server.properties
        fi
      }

      set_property allow-flight true
      set_property motd "All the Mods 11"
      set_property max-tick-time 180000
      set_property max-players 20
      set_property op-permission-level 4
      set_property simulation-distance 5
      set_property view-distance 8
      set_property online-mode true
      set_property use-native-transport true
      if [ -f /root/allthemons-rcon.password ]; then
        set_property enable-rcon true
        set_property rcon.port 25575
        set_property rcon.password "$(cat /root/allthemons-rcon.password)"
      fi

      # BlueMap 5.7 crashes ATM 11 / NeoForge 26 module scanning. Keep the
      # managed jar out of this server root until a compatible build is pinned.
      rm -f ${atm11Root}/mods/bluemap-5.7-neoforge.jar
    '';
    script = ''
      cd ${atm11Root}
      exec ./startserver.sh
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = "30s";
      KillSignal = "SIGINT";
      TimeoutStopSec = "180s";
      MemoryHigh = "14G";
      MemoryMax = "15G";
      LimitNOFILE = 1048576;
    };
  };

  systemd.services.allthemons-1-0-0-rc-6 = {
    enable = false;
    description = "All the Mons 1.0.0-rc.6 Minecraft server";
    wantedBy = ["multi-user.target"];
    unitConfig.Conflicts = [
      "atm-10-tts.service"
      "atm10-6-6.service"
      "atm10-8-0.service"
      "atm11-0-2-0.service"
      "allthemons-1-0-0-rc-5.service"
      "cutie-craft.service"
      "cus2.service"
    ];
    path = with pkgs; [
      coreutils
      curl
      gawk
      jdk21_headless
      wget
    ];
    environment = {
      ATM10_JAVA = "${pkgs.jdk21_headless}/bin/java";
      ATM10_RESTART = "false";
    };
    preStart = ''
      if [ ! -f ${allTheMonsRoot}/startserver.sh ]; then
        echo "Missing ${allTheMonsRoot}/startserver.sh. Extract ServerFiles-1.0.0-rc.6.zip into ${allTheMonsRoot} before starting this service."
        exit 1
      fi

      install -m 0644 ${minecraftJvmArgs} ${allTheMonsRoot}/user_jvm_args.txt
      printf 'eula=true\n' > ${allTheMonsRoot}/eula.txt
      if grep -q '^view-distance=' ${allTheMonsRoot}/server.properties; then
        sed -i 's/^view-distance=.*/view-distance=12/' ${allTheMonsRoot}/server.properties
      else
        printf 'view-distance=12\n' >> ${allTheMonsRoot}/server.properties
      fi
      chmod +x ${allTheMonsRoot}/startserver.sh

      install -D -m 0644 ${bluemapJar} ${allTheMonsRoot}/mods/bluemap-5.7-neoforge.jar
      install -D -m 0644 ${chunkyJar} ${allTheMonsRoot}/mods/Chunky-NeoForge-1.4.23.jar
      install -D -m 0644 ${bluemapCoreConfig} ${allTheMonsRoot}/config/bluemap/core.conf
      install -D -m 0644 ${bluemapWebappConfig} ${allTheMonsRoot}/config/bluemap/webapp.conf
      install -D -m 0644 ${bluemapWebserverConfig} ${allTheMonsRoot}/config/bluemap/webserver.conf
      install -D -m 0644 ${bluemapPluginConfig} ${allTheMonsRoot}/config/bluemap/plugin.conf
    '';
    script = ''
      cd ${allTheMonsRoot}
      exec ./startserver.sh
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = "30s";
      KillSignal = "SIGINT";
      TimeoutStopSec = "120s";
      MemoryHigh = "14G";
      MemoryMax = "16G";
    };
  };
}
