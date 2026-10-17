{inputs, ...}: let
  deployedPackages = inputs.nixpkgs-nook-apps.legacyPackages.x86_64-linux;
in {
  nixos.nook = {
    lib,
    pkgs,
    ...
  }: let
    yaml = pkgs.formats.yaml {};
    heading = name: icon: {
      type = "heading";
      heading = name;
      inherit icon;
    };
    tile = entity: name: {
      type = "tile";
      inherit entity name;
    };
    section = cards: {
      type = "grid";
      inherit cards;
    };
    navigate = name: icon: destination: {
      type = "button";
      inherit name icon;
      show_state = false;
      tap_action = {
        action = "navigate";
        navigation_path = destination;
      };
      hold_action.action = "none";
    };
    graph = entity: name: color: {
      type = "custom:mini-graph-card";
      inherit name;
      entities = [entity];
      hours_to_show = 6;
      points_per_hour = 12;
      update_interval = 60;
      height = 110;
      line_width = 2;
      line_color = color;
      animate = false;
      hour24 = true;
      show = {
        fill = "fade";
        extrema = true;
      };
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    };
    view = title: sections: {
      inherit title sections;
      path = "overview";
      type = "sections";
      max_columns = 3;
      theme = "Home";
      header = {
        layout = "start";
        card = {
          type = "markdown";
          content = "# ${title}";
          text_only = true;
        };
      };
    };
    activeCycle = [
      {
        condition = "or";
        conditions = [
          {
            condition = "state";
            entity = "sensor.laundry_room_washer_machine_state";
            state = "run";
          }
          {
            condition = "state";
            entity = "sensor.laundry_room_washer_machine_state";
            state = "pause";
          }
        ];
      }
    ];
    dashboards = {
      home-main = {
        title = "Home";
        icon = "mdi:home-heart";
        views = [
          (view "Home" [
            (section [
              (heading "Electricity" "mdi:lightning-bolt")
              (graph "sensor.home_power" "Grid power" "#c5ef9a")
              (tile "sensor.home_quarter_hour_average_power" "15-minute average")
              (tile "sensor.home_monthly_power_peak" "Monthly peak")
              (navigate "Energy details" "mdi:chart-areaspline" "/home-energy/overview")
            ])
            (section [
              (heading "Laundry room" "mdi:washing-machine")
              (tile "sensor.laundry_room_washer_machine_state" "Washer")
              (tile "sensor.laundry_room_washer_job_state" "Current job")
              (tile "sensor.laundry_room_washer_power" "Washer power")
              (tile "binary_sensor.laundry_room_washer_remote_control" "Remote control")
              {
                type = "conditional";
                conditions = activeCycle;
                card = tile "sensor.laundry_room_washer_completion_time" "Finishes at";
              }
              (navigate "Laundry" "mdi:washing-machine" "/home-laundry/overview")
            ])
            (section [
              (heading "At home" "mdi:home-outline")
              {
                type = "weather-forecast";
                entity = "weather.forecast_home";
                show_forecast = true;
                forecast_type = "daily";
              }
              {
                type = "media-control";
                entity = "media_player.bedroom_display";
              }
              (navigate "Network" "mdi:lan" "/home-network/overview")
            ])
          ])
        ];
      };
      home-energy = {
        title = "Energy details";
        icon = "mdi:chart-areaspline";
        views = [
          (view "Energy" [
            (section [
              (heading "Right now" "mdi:transmission-tower")
              (graph "sensor.home_power" "Grid power" "#c5ef9a")
              (tile "sensor.home_quarter_hour_average_power" "15-minute average")
              (tile "sensor.home_monthly_power_peak" "Monthly peak")
              (tile "sensor.home_voltage" "Voltage")
              (tile "sensor.home_current" "Current")
            ])
            (section [
              (heading "Consumption" "mdi:chart-bar")
              {type = "energy-date-selection";}
              {
                type = "energy-usage-graph";
                title = "Electricity import & export";
              }
              {
                type = "energy-gas-graph";
                title = "Gas";
              }
            ])
            (section [
              (heading "Appliances" "mdi:washing-machine")
              {
                type = "energy-devices-graph";
                title = "Appliance energy";
              }
              (graph "sensor.laundry_room_washer_power" "Washer power" "#8dcaff")
              (navigate "Full Energy dashboard" "mdi:lightning-bolt" "/energy")
            ])
          ])
        ];
      };
      home-laundry = {
        title = "Laundry";
        icon = "mdi:washing-machine";
        views = [
          (view "Laundry" [
            (section [
              (heading "Samsung washer" "mdi:washing-machine")
              (tile "sensor.laundry_room_washer_machine_state" "Washer")
              (tile "sensor.laundry_room_washer_job_state" "Current job")
              (tile "binary_sensor.laundry_room_washer_power" "Power")
              (tile "binary_sensor.laundry_room_washer_child_lock" "Child lock")
              {
                type = "conditional";
                conditions = activeCycle;
                card = tile "sensor.laundry_room_washer_completion_time" "Finishes at";
              }
              {
                type = "entities";
                title = "Cycle settings";
                show_header_toggle = false;
                entities = [
                  {
                    entity = "select.laundry_room_washer_water_temperature";
                    name = "Temperature";
                    type = "simple-entity";
                  }
                  {
                    entity = "select.laundry_room_washer_spin_level";
                    name = "Spin speed";
                    type = "simple-entity";
                  }
                  {
                    entity = "number.laundry_room_washer_rinse_cycles";
                    name = "Rinse cycles";
                    type = "simple-entity";
                  }
                ];
              }
            ])
            (section [
              (heading "Power & energy" "mdi:lightning-bolt")
              (graph "sensor.laundry_room_washer_power" "Washer power" "#8dcaff")
              {
                type = "statistics-graph";
                title = "Daily washer energy";
                chart_type = "bar";
                period = "day";
                days_to_show = 7;
                stat_types = ["change"];
                entities = ["sensor.laundry_room_washer_energy"];
              }
            ])
            (section [
              (heading "Controls" "mdi:tune-variant")
              (tile "binary_sensor.laundry_room_washer_remote_control" "Remote control")
              # Do not offer start/pause/settings while Smart Control is off.
              {
                type = "conditional";
                conditions = [
                  {
                    condition = "state";
                    entity = "binary_sensor.laundry_room_washer_remote_control";
                    state = "off";
                  }
                ];
                card = {
                  type = "markdown";
                  content = "Enable **Smart Control** on the washer to use remote controls.";
                };
              }
              {
                type = "conditional";
                conditions = [
                  {
                    condition = "state";
                    entity = "binary_sensor.laundry_room_washer_remote_control";
                    state = "on";
                  }
                ];
                card = {
                  type = "entities";
                  title = "Remote controls";
                  show_header_toggle = false;
                  entities = [
                    {
                      entity = "select.laundry_room_washer";
                      name = "Machine control";
                    }
                    {
                      entity = "select.laundry_room_washer_water_temperature";
                      name = "Temperature";
                    }
                    {
                      entity = "select.laundry_room_washer_spin_level";
                      name = "Spin speed";
                    }
                    {
                      entity = "number.laundry_room_washer_rinse_cycles";
                      name = "Rinse cycles";
                    }
                    {
                      entity = "switch.laundry_room_washer_bubble_soak";
                      name = "Bubble soak";
                    }
                  ];
                };
              }
              (navigate "Energy details" "mdi:chart-areaspline" "/home-energy/overview")
            ])
          ])
        ];
      };
      home-network = {
        title = "Network";
        icon = "mdi:lan";
        require_admin = true;
        views = [
          (view "Network" [
            (section [
              (heading "Gateway" "mdi:router-network")
              (tile "sensor.lisa_home_state" "Connection")
              (tile "sensor.lisa_home_uptime" "Online since")
              (graph "sensor.lisa_home_cpu_utilization" "Gateway CPU" "#c5ef9a")
              (tile "sensor.lisa_home_memory_utilization" "Memory")
            ])
            (section [
              (heading "Wi-Fi" "mdi:wifi")
              (tile "sensor.u7_pro_state" "Access point")
              (tile "sensor.u7_pro_uptime" "Online since")
              (graph "sensor.u7_pro_cpu_utilization" "Access point CPU" "#8dcaff")
              (tile "sensor.u7_pro_memory_utilization" "Memory")
              {
                type = "entities";
                title = "Connected clients";
                show_header_toggle = false;
                entities = [
                  {
                    entity = "sensor.lisa_ent_clients";
                    name = "Main Wi-Fi";
                  }
                  {
                    entity = "sensor.lisa_iot_clients";
                    name = "IoT Wi-Fi";
                  }
                  {
                    entity = "sensor.lisa_vpn_clients";
                    name = "VPN Wi-Fi";
                  }
                ];
              }
            ])
            (section [
              (heading "Minecraft" "mdi:minecraft")
              (tile "binary_sensor.atm_bylisa_dev_status" "Server")
              (tile "sensor.atm_bylisa_dev_players_online" "Players online")
              (graph "sensor.atm_bylisa_dev_latency" "Server latency" "#e6c28b")
              (tile "sensor.atm_bylisa_dev_version" "Version")
            ])
          ])
        ];
      };
    };
  in {
    services.home-assistant = {
      customLovelaceModules = [deployedPackages.home-assistant-custom-lovelace-modules.mini-graph-card];
      config = {
        frontend.themes.Home = {
          "primary-background-color" = "#000000";
          "secondary-background-color" = "#111111";
          "card-background-color" = "#111111";
          "ha-card-background" = "#111111";
          "primary-text-color" = "#ffffff";
          "secondary-text-color" = "#a3a3a3";
          "primary-color" = "#c5ef9a";
          "accent-color" = "#c5ef9a";
          "divider-color" = "#292929";
          "ha-card-border-color" = "#292929";
          "ha-card-border-radius" = "16px";
          "ha-card-box-shadow" = "none";
        };
        lovelace.dashboards =
          lib.mapAttrs (slug: dashboard: {
            mode = "yaml";
            filename = "${yaml.generate "${slug}.yaml" {inherit (dashboard) title views;}}";
            inherit (dashboard) title icon;
            show_in_sidebar = true;
            require_admin = dashboard.require_admin or false;
          })
          dashboards;
      };
    };
  };
}
