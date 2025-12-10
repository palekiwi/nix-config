{ ... }:

{
  imports = [
    ./zones.nix
    ./lights.nix
    # ./helpers.nix      # TODO: Add next
    # ./templates.nix    # TODO: Add after helpers
    # ./scenes.nix       # TODO: Add after templates
    # ./automations      # TODO: Add automations last
  ];

  services.home-assistant = {
    enable = true;

    config = {
      default_config = {};

      http = {
        base_url = "ha.paradise-liberty.ts.net";
        use_x_forwarded_for = true;
        trusted_proxies = [
          "100.85.171.76"
          "100.110.79.91"
          "10.0.2.100"
          "10.89.0.0/24"
        ];
      };

      tts = [
        { platform = "google_translate"; }
      ];

      "automation manual" = [];
      "automation ui" = "!include automations.yaml";
    };

    lovelace = {
      mode = "yaml";
      dashboards.lovelace-main = {
        mode = "yaml";
        filename = "manual/dashboards/main/main.yaml";
        title = "Generated";
        icon = "mdi:tools";
        show_in_sidebar = true;
        require_admin = true;
      };
    };

    configDir = "/var/lib/hass";

    # Components required by configuration and integrations
    extraComponents = [
      # Required for onboarding flow
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"

      # Recommended for fast zlib compression
      "isal"

      # MQTT integration (UI-configured via .storage/)
      # Required for zigbee2mqtt device automations
      "mqtt"

      # Components used in configuration.yaml
      "default_config"
      "http"
      "frontend"
      "tts"
      "lovelace"

      # Components used in manual/ directory
      "automation"
      "input_datetime"
      "input_number"
      "input_text"
      "input_boolean"
      "template"
      "scene"
      "script"
      "zone"
      "light"
    ];
  };

  # Service dependencies and ordering
  systemd.services.home-assistant = {
    after = [ "mosquitto.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      5050 # app-daemon
      8123 # home-assistant
    ];
  };
}
