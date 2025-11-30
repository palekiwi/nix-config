{ config, ...}:

{
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;
      permit_join = false;
      frontend.port = 8080;
      mqtt = {
        base_topic = "zigbee2mqtt";
        server = "mqtt://100.122.42.74:1883";
      };
      serial.port = "/dev/ttyUSB0";
    };
  };

  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    requires = [ "mosquitto.service" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets."zigbee2mqtt".path;
    };
  };

  services.udev.extraRules = ''
    KERNEL=="ttyUSB0", SUBSYSTEM=="tty", OWNER="zigbee2mqtt", GROUP="dialout", MODE="0660"
  '';
}
