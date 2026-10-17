{
  nixos.nook.services.home-assistant.config.rest = [
    {
      # HWE-P1 3c39e72b2b5a: local API verified from Nook, 2026-10-17.
      # YAML REST sensors keep this setup in Nix; no UI config entry needed.
      # Home Assistant's mDNS resolver follows DHCP address changes.
      resource = "http://p1meter-2B2B5A.local/api/v1/data";
      scan_interval = 10;
      timeout = 5;
      sensor = [
        {
          name = "Home electricity import";
          unique_id = "homewizard_3c39e72b2b5a_total_power_import_kwh";
          value_template = "{{ value_json.total_power_import_kwh | default(none) }}";
          device_class = "energy";
          state_class = "total_increasing";
          unit_of_measurement = "kWh";
        }
        {
          name = "Home electricity export";
          unique_id = "homewizard_3c39e72b2b5a_total_power_export_kwh";
          value_template = "{{ value_json.total_power_export_kwh | default(none) }}";
          device_class = "energy";
          state_class = "total_increasing";
          unit_of_measurement = "kWh";
        }
        {
          name = "Home power";
          unique_id = "homewizard_3c39e72b2b5a_active_power_w";
          value_template = "{{ value_json.active_power_w | default(none) }}";
          device_class = "power";
          state_class = "measurement";
          unit_of_measurement = "W";
        }
        {
          name = "Home voltage";
          unique_id = "homewizard_3c39e72b2b5a_active_voltage_l1_v";
          value_template = "{{ value_json.active_voltage_l1_v | default(none) }}";
          device_class = "voltage";
          state_class = "measurement";
          unit_of_measurement = "V";
        }
        {
          name = "Home current";
          unique_id = "homewizard_3c39e72b2b5a_active_current_a";
          value_template = "{{ value_json.active_current_a | default(none) }}";
          device_class = "current";
          state_class = "measurement";
          unit_of_measurement = "A";
        }
        {
          name = "Home electricity tariff";
          unique_id = "homewizard_3c39e72b2b5a_active_tariff";
          value_template = "{{ value_json.active_tariff | default(none) }}";
        }
        {
          name = "Home quarter-hour average power";
          unique_id = "homewizard_3c39e72b2b5a_active_power_average_w";
          value_template = "{{ value_json.active_power_average_w | default(none) }}";
          device_class = "power";
          state_class = "measurement";
          unit_of_measurement = "W";
        }
        {
          # The local API spells this field "montly". It resets each month.
          name = "Home monthly power peak";
          unique_id = "homewizard_3c39e72b2b5a_montly_power_peak_w";
          value_template = "{{ value_json.montly_power_peak_w | default(none) }}";
          device_class = "power";
          state_class = "measurement";
          unit_of_measurement = "W";
        }
        {
          name = "Home gas consumption";
          unique_id = "homewizard_3c39e72b2b5a_total_gas_m3";
          value_template = "{{ value_json.total_gas_m3 | default(none) }}";
          device_class = "gas";
          state_class = "total_increasing";
          unit_of_measurement = "m³";
        }
      ];
    }
  ];
}
