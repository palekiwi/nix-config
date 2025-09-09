{ pkgs, lib, ... }:

let
  lights_kitchen = [
    "light.kitchen"
    "light.kitchen_ceiling"
    "light.workbench"
  ];

  lights = [
    "light.desk"
    "light.workbench"
  ] ++ lights_kitchen;

  options = [
    "kitchen_off"
    "fan_toggle"
  ] ++ lights;

  plug_sonoff = "switch.0x00124b0026b87179";

  launcher = pkgs.writeShellScript "launcher" ''
    dmenu -i -nb \#1d1f21 -nf \#D3D7CF -sb \#37ADD4 -sf \#192330 -fn 11 -p "Home Assistant"
  '';

  hass = pkgs.writeShellScript "hass" ''
    hass-cli --server $(cat /run/secrets/hass/server) --token $(cat /run/secrets/hass/token) $@
  '';
in

pkgs.writeShellScriptBin "dmenu_hass" ''
  choice=$(echo "${lib.concatStringsSep "\n" options}" | ${launcher})

  case "$choice" in
    kitchen_off)
      ${hass} state turn_off ${lib.concatStringsSep " " lights_kitchen}
    ;;
    fan_toggle)
      ${hass} state toggle ${plug_sonoff}
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
