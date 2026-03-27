{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/keys.txt";

  sops.secrets."appdaemon" = { owner = "root"; };
  sops.secrets."cachix/personal/token" = { owner = "pl"; };
  sops.secrets."hass/server" = { owner = "pl"; };
  sops.secrets."hass/token" = { owner = "pl"; };
  sops.secrets."nextcloud/admin/password" = { owner = "nextcloud"; };
  sops.secrets."zigbee2mqtt" = { owner = "zigbee2mqtt"; };
}
