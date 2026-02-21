{ ... }:

{
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/keys.txt";

  sops.secrets."airbrake/api_key" = { owner = "pl"; };
  sops.secrets."cachix/personal/token" = { owner = "pl"; };
  sops.secrets."cachix/github_actions/token" = { owner = "pl"; };
  sops.secrets."github/palekiwi/gh_cli" = { owner = "pl"; };
  sops.secrets."hass/server" = { owner = "pl"; };
  sops.secrets."hass/token" = { owner = "pl"; };
  sops.secrets."jira/email" = { owner = "pl"; };
  sops.secrets."jira/token" = { owner = "pl"; };
  sops.secrets."opencode/api_key" = { owner = "pl"; };
  sops.secrets."zai_coding_plan/api_key" = { owner = "pl"; };
  sops.secrets."context7/api_key" = { owner = "pl"; };
  sops.secrets."taskwarrior/sync/encryption_secret" = { owner = "pl"; };

  sops.secrets."spabreaks/gemini_api_key" = { owner = "pl"; };
  sops.secrets."spabreaks/github_readonly" = { owner = "pl"; };
  sops.secrets."spabreaks/google_generative_ai_api_key" = { owner = "pl"; };
  sops.secrets."spabreaks/gmail/nixos" = { owner = "pl"; };

  sops.secrets."gotify/token" = { owner = "notifications-server"; };
}
