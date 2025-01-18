{ pkgs, ... }:

pkgs.writeShellScriptBin "hass" ''
  hass-cli --server $(cat /run/secrets/hass/server) --token $(cat /run/secrets/hass/token) $@
''
