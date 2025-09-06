{ pkgs }:

pkgs.writers.writeNuBin "dmenu_audio-sinks" ''
  let options_pale = ["TOZO OpenBuds", "Speaker"]
  let launcher = 'dmenu -i -nb #1d1f21 -nf #D3D7CF -sb #5294e2 -sf #2f343f -fn 11'

  if (hostname | str trim) == "pale" {
    let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#5294e2" "-sf" "#2f343f" "-fn" "11" "-p" "PulseAudio Sink: "]
    let choice = ($options_pale | str join "\n" | run-external "dmenu" ...$dmenu_options)

    match $choice {
      "TOZO OpenBuds" => {
        bluetoothctl connect 58:FC:C6:CE:92:70
        sleep 1sec
        pactl set-default-sink bluez_output.58_FC_C6_CE_92_70.1
      }
      "Speaker" => {
        pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI1__sink
      }
      _ => {
        exit 1
      }
    }
  } else {
    notify-send "setting unavailable on this host"
    exit 1
  }
''
