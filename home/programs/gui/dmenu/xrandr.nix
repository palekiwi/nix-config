{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" ''
  let pale_builtin = "eDP-1-1"
  let pale_external = "DP-1-2"
  let pale_tablet = "DP-1-3"

  let options_pale = ["builtin", "external", "dual-external"]
  let options_deck = ["builtin", "external", "dual", "presentation"]

  let deck_builtin = "eDP-1"
  let deck_external = "DisplayPort-0"

  let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#5294e2" "-sf" "#2f343f" "-fn" "11" "-p" "xrandr profile: "]

  def restart_wm [] {
    awesome-client "awesome.restart()"
  }

  let host = (hostname | str trim)

  match $host {
    "deck" => {
      let choice = ($options_deck | str join "\n" | run-external "dmenu" ...$dmenu_options)
      match $choice {
        "builtin" => {
          xrandr --output $deck_builtin --rotate right --auto --primary
          xrandr --output $deck_external --off
          restart_wm
        }
        "external" => {
          xrandr --output $deck_external --auto --primary
          xrandr --output $deck_builtin --off
          restart_wm
        }
        "dual" => {
          xrandr --output $deck_external --auto --primary
          xrandr --output $deck_builtin --rotate right --auto --below $deck_external
          restart_wm
        }
        _ => {
          exit 1
        }
      }
    }
    "pale" => {
      let choice = ($options_pale | str join "\n" | run-external "dmenu" ...$dmenu_options)
      match $choice {
        "builtin" => {
          xrandr --output $pale_builtin --auto --primary
          xrandr --output $pale_external --off
          xrandr --output $pale_tablet --off
          restart_wm
        }
        "external" => {
          xrandr --output $pale_external --auto --primary
          xrandr --output $pale_builtin --off
          xrandr --output $pale_tablet --off
          restart_wm
        }
        "dual-external" => {
          xrandr --output $pale_external --auto --primary
          xrandr --output $pale_builtin --off
          xrandr --output $pale_tablet --auto --pos 760x1440 --rotate inverted
          restart_wm
        }
        _ => {
          exit 1
        }
      }
    }
    _ => {
      notify-send "xrandr unavailable on this host"
      exit 1
    }
  }
''
