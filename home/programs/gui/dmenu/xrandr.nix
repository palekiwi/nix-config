{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" (builtins.readFile ./xrandr.nu)
