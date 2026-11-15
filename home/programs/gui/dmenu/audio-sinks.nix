{ pkgs }:

pkgs.writers.writeNuBin "dmenu_audio-sinks" ''
  let options_pale = ["Speakers", "Earbuds: voice only", "Earbuds: calls", "Earbuds: disconnect"]
  let earbuds = "58:FC:C6:CE:92:70"
  let earbuds_sink = "bluez_output.58_FC_C6_CE_92_70.1"
  let speakers_sink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__HDMI1__sink"

  if (hostname | str trim) == "pale" {
    let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#5294e2" "-sf" "#2f343f" "-fn" "11" "-p" "PulseAudio Sink: "]
    let choice = ($options_pale | str join "\n" | run-external "dmenu" ...$dmenu_options)

    match $choice {
      "Speakers" => {
        pactl set-default-sink $speakers_sink
      }
      "Earbuds: voice only" => {
        bluetoothctl connect $earbuds
        sleep 1sec
        pactl set-default-sink $speakers_sink
      }
      "Earbuds: calls" => {
        bluetoothctl connect $earbuds
        sleep 1sec
        pactl set-default-sink $earbuds_sink
      }
      "Earbuds: disconnect" => {
        bluetoothctl disconnect $earbuds
        pactl set-default-sink $speakers_sink
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
