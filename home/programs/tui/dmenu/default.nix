{ pkgs, ... }:

[
  (import ./activity_log.nix { inherit pkgs; })
]
