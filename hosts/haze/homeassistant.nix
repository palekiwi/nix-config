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

  # Ensure config directory exists with proper permissions
  # Before first nixos-rebuild:
  #   sudo cp -r /srv/ha/homeassistant/config /var/lib/hass
  # The Z directive will automatically fix ownership recursively on boot
  # Original config remains untouched at /srv/ha/homeassistant/config
  systemd.tmpfiles.rules = [
    "d /var/lib/hass 0755 hass hass"
    "Z /var/lib/hass 0755 hass hass -"  # Recursively set ownership and permissions
  ];

  # Service dependencies and ordering
  systemd.services.home-assistant = {
    after = [ "mosquitto.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # TODO: AppDaemon migration - add after Home Assistant is verified working
  # See .agents/homelab/ha/ha.kube.yml for current container config
}
