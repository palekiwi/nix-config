{ pkgs, ... }:

[
  (import ./set_pr_info.nix { inherit pkgs; })
]
