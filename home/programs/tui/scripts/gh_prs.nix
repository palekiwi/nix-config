{ pkgs, ... }:

pkgs.writers.writeNuBin "gh_prs" (builtins.readFile ./gh_prs.nu)
