{ ... }:

{
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/keys.txt";

  sops.secrets."hass/server" = { owner = "pl"; };
  sops.secrets."hass/token" = { owner = "pl"; };
  sops.secrets."jira/token" = { owner = "pl"; };
  sops.secrets."jira/email" = { owner = "pl"; };
  sops.secrets."github/prompt-assist" = { owner = "pl"; };
}
