{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" ''
    let pale = {
      builtin: "eDP-1-1"
      external: "DP-1-2"
      tablet: "DP-1-3"
    }

    let deck = {
      builtin: "eDP-1"
      external: "DisplayPort-0"
    }

    let opts = {
      pale: ["builtin", "external", "dual", "dual-external"]
      deck: ["builtin", "external", "dual"]
    }

    def restart_wm [] {
      awesome-client "awesome.restart()"
    }

    def run_dmenu [opts] {
      $opts | dmenu -i -nb "#1d1f21" -nf "#D3D7CF" -sb "#5294e2" -sf "#2f343f" -fn "11" -p "xrandr profile: "
    }

    let host = (hostname | str trim)

    match $host {
      "deck" => {
        let choice = ($options_deck | str join "\n" | run_dmenu $in)
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
        let choice = ($options_pale | str join "\n" | run_dmenu $in)
        match $choice {
          "builtin" => {
            xrandr --output $pale.builtin --auto --primary
            xrandr --output $pale.external --off
            xrandr --output $pale.tablet --off
            restart_wm
          }
          "external" => {
            xrandr --output $pale.external --auto --primary
            xrandr --output $pale.builtin --off
            xrandr --output $pale.tablet --off
            restart_wm
          }
          "dual" => {
            xrandr --output $pale.builtin --auto --primary
            xrandr --output $pale.external --off
            xrandr --output $pale.tablet --auto --left-of $pale.builtin --rotate inverted
            restart_wm
          }
          "dual-external" => {
            xrandr --output $pale.external --auto --primary
            xrandr --output $pale.builtin --off
            xrandr --output $pale.tablet --auto --pos 760x1440 --rotate inverted
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
