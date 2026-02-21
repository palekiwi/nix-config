{ pkgs }:

pkgs.writers.writeNuBin "dmenu_tmux" (builtins.readFile ./tmux.nu)
