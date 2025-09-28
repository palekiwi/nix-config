{ pkgs }:

pkgs.writers.writeNuBin "dmenu_process" ''
  let options = ["sxhkd" "xmodmap" "picom"]
  let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#ffb05f" "-sf" "#192330" "-fn" "11" "-p" "Restart process: "]

  let choice = ($options | str join "\n" | run-external "dmenu" ...$dmenu_options)

  match $choice {
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
