{ pkgs, lib, ... }:

[
  (import ./activity_log.nix { inherit pkgs; })
  (import ./hass.nix { inherit pkgs lib; })
  (import ./quit.nix { inherit pkgs; })
]
