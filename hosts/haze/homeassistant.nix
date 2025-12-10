{
  services.home-assistant = {
    enable = true;

    config = {
      default_config = { };
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

      "automation manual" = [ ];
      "automation ui" = "!include automations.yaml";

      zone = [
        {
          name = "Home";
          latitude = 25.166340194340584;
          longitude = 121.48607472560579;
          radius = 100;
          icon = "mdi:home";
        }
        {
          name = "Work";
          latitude = 25.069146451733037;
          longitude = 121.58090808028379;
          radius = 100;
          icon = "mdi:briefcase";
        }
      ];

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

  # TODO: study https://github.com/Mic92/dotfiles/tree/393539385b0abfc3618e886cd0bf545ac24aeb67/machines/eve/modules/home-assistant

  # TODO: AppDaemon migration - add after Home Assistant is verified working
  # See .agents/homelab/ha/ha.kube.yml for current container config
}
