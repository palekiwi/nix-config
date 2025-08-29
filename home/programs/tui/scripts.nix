{ pkgs, config, lib, ... }:

{
  home.packages = [
    (import ./scripts/dmenu_hass.nix { inherit pkgs lib config; })
    (import ./scripts/generate_port_from_path.nix { inherit pkgs; })
    (import ./scripts/hass.nix { inherit pkgs config; })
    (import ./scripts/yt-subs.nix { inherit pkgs lib config; })
  ];
}
