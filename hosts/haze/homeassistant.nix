{
  services.home-assistant = {
    enable = true;

    # Imperative mode - uses copy of existing config directory
    # Original config remains intact at /srv/ha/homeassistant/config
    # This preserves all UI configurations, .storage/ data, and manual/ files
    config = null;
    lovelaceConfig = null;
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
