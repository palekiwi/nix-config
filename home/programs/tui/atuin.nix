{ ... }:

{
  programs.atuin = {
    enable = true;
    enableNushellIntegration = true;
    settings = import ./atuin-settings.nix;
  };
}
