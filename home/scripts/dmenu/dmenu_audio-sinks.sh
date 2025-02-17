#!/usr/bin/env bash

declare -a options_pale=(
"TOZO OpenBuds"
"Speaker"
)
launcher='dmenu -i -nb #1d1f21 -nf #D3D7CF -sb #5294e2 -sf #2f343f -fn 11'

if [[ $(hostname -s) == "pale" ]];
then
  choice=$(echo "$(printf '%s\n' "${options_pale[@]}")" | $launcher -p 'PulseAudio Sink: ')
  case "$choice" in
    "TOZO OpenBuds")
        bluetoothctl connect 58:FC:C6:CE:92:70
        sleep 1
        pactl set-default-sink bluez_output.58_FC_C6_CE_92_70.1
    ;;
    "Speaker")
        pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI1__sink
    ;;
    *)
      exit 1
    ;;
  esac
else
  notify-send "setting unavailable on this host"
  exit 1
fi
