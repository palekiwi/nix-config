{ pkgs, ... }:

pkgs.writeShellScriptBin "hass" ''
  set -a
  source ~/.hass-cli
  set +a

  hass-cli $@
''
