{ pkgs, lib, ... }:

{
  home.packages = import ./dmenu { inherit pkgs lib; };

  home.file.".dmenu/process".source = ../../scripts/dmenu/dmenu_process.sh;
}
