{ pkgs, config, ... }:

if config.fedora then
  pkgs.writeShellScriptBin "hass" ''
    hass-cli --server $(cat ~/.hass_server) --token $(cat ~/.hass_token) $@
  ''
else
  pkgs.writeShellScriptBin "hass" ''
    hass-cli --server $(cat /run/secrets/hass/server) --token $(cat /run/secrets/hass/token) $@
  ''
