{ pkgs, lib, ... }:

{
  home.packages = import ./dmenu { inherit pkgs lib; };

  home.file.".dmenu/hass".source = ../../scripts/dmenu/dmenu_hass.sh;
  home.file.".dmenu/process".source = ../../scripts/dmenu/dmenu_process.sh;
  home.file.".dmenu/run".source = ../../scripts/dmenu/dmenu_run.sh;
}
