{ pkgs, lib, config, ... }:

let
  options = [
    "light.kitchen_off"
    "light.desk"
    "light.workbench"
  ];

  launcher = pkgs.writeShellScript "launcher" ''
    dmenu -i -nb \#1d1f21 -nf \#D3D7CF -sb \#37ADD4 -sf \#192330 -fn 11 -p "Home Assistant"
  '';

  hass = if config.fedora then
    pkgs.writeShellScript "hass" ''
      hass-cli --server $(cat ~/.hass_server) --token $(cat ~/.hass_token) $@
    ''
  else
    pkgs.writeShellScript "hass" ''
      hass-cli --server $(cat /run/secrets/hass/server) --token $(cat /run/secrets/hass/token) $@
    '';
in

pkgs.writeShellScriptBin "dmenu_hass" ''
  choice=$(echo "${lib.concatStringsSep "\n" options}" | ${launcher})

  case "$choice" in
    ${lib.concatMapStrings
      (option: ''
        ${option})
          ${hass} state toggle $choice
        ;;
      '')
      options
    }
    *)
      exit 1
    ;;
  esac
''
