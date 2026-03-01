{ pkgs }:

pkgs.writers.writeNuBin "dmenu_process" ''
  let options = ["handy" "opentabletdriver" "sxhkd" "xmodmap" "picom"]
  let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#ffb05f" "-sf" "#192330" "-fn" "11" "-p" "Restart process: "]

  let choice = ($options | str join "\n" | run-external "dmenu" ...$dmenu_options)

  match $choice {
    "handy" => {
      systemctl --user restart handy
    },
    "opentabletdriver" => {
      systemctl --user restart opentabletdriver
    },
    "picom" => {
      killall picom
      picom
    },
    "sxhkd" => {
      pkill -USR1 -x sxhkd
      notify-send -t 600 "Restarted" $choice
    },
    "xmodmap" => {
      xmodmap ~/.Xmodmap
      notify-send -t 600 "Restarted" $choice
    },
    _ => { exit 1 }
  }
''
