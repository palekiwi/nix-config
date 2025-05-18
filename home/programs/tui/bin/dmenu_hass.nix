{ pkgs, lib, config, ... }:

let
  lights_kitchen = [
    "light.kitchen"
    "light.kitchen_ceiling"
  ];

  lights = [
    "light.desk"
    "light.workbench"
  ] ++ lights_kitchen;

  options = [
    "kitchen_off"
  ] ++ lights;

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
    kitchen_off)
      ${hass} state turn_off ${lib.concatStringsSep " " lights_kitchen}
    ;;
    ${lib.concatMapStrings
      (light: ''
        ${light})
          ${hass} state toggle $choice
        ;;
      '')
      lights
    }
    *)
      exit 1
    ;;
  esac
''
