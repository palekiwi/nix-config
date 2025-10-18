{ ... }:

{
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/keys.txt";

  sops.secrets."airbrake/api_key" = { owner = "pl"; };
  sops.secrets."github/pats/palekiwi/gemini-cli" = { owner = "pl"; };
  sops.secrets."hass/server" = { owner = "pl"; };
  sops.secrets."hass/token" = { owner = "pl"; };
  sops.secrets."jira/email" = { owner = "pl"; };
  sops.secrets."jira/token" = { owner = "pl"; };
  sops.secrets."opencode/api_key" = { owner = "pl"; };
  sops.secrets."zai_coding_plan/api_key" = { owner = "pl"; };

  sops.secrets."gotify/token" = { owner = "notifications-server"; };
}
