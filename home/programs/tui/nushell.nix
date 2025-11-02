{ config, ... }:
{
  programs = {
    carapace.enable = true;
    carapace.enableNushellIntegration = true;
  };

  services.gpg-agent.enableNushellIntegration = true;

  xdg.configFile."nushell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/config/nushell";
}
