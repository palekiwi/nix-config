{ ... }:

{
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/primary.txt";

  sops.secrets."hass/server" = { owner = "pl"; };
  sops.secrets."hass/token" = { owner = "pl"; };
}
