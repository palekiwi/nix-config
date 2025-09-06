{ pkgs, lib, ... }:

[
  (import ./activity_log.nix { inherit pkgs; })
  (import ./audio-sinks.nix { inherit pkgs; })
  (import ./hass.nix { inherit pkgs lib; })
  (import ./quit.nix { inherit pkgs; })
  (import ./xrandr.nix { inherit pkgs; })
]
