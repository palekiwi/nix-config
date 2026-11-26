{ ... }:
{
  home.username = "pl";
  home.homeDirectory = "/home/pl";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  xdg.configFile."sesh/sesh.toml".source = ../../../home/config/sesh/sesh.toml;
}
