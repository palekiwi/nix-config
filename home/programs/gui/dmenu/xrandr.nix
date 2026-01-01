{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" ''
    let pale = {
      builtin: "eDP-1-1"
      external: "DP-1-2"
      tablet: "DP-1-3"
    }

    let pale_actions = {
       builtin: { ||
         xrandr --output $pale.builtin --auto --primary
         xrandr --output $pale.external --off
         xrandr --output $pale.tablet --off
       }
       external: { ||
         xrandr --output $pale.external --auto --primary
         xrandr --output $pale.builtin --off
         xrandr --output $pale.tablet --off
       }
       dual: { ||
         xrandr --output $pale.builtin --auto --primary
         xrandr --output $pale.external --off
         xrandr --output $pale.tablet --auto --left-of $pale.builtin --rotate inverted
       }
       "dual-external": { ||
         xrandr --output $pale.external --auto --primary
         xrandr --output $pale.builtin --off
         xrandr --output $pale.tablet --auto --pos 760x1440 --rotate inverted
       }
    }

    let deck = {
      builtin: "eDP-1"
      external: "DisplayPort-0"
    }

    let deck_actions = {
       builtin: { ||
         xrandr --output $deck.builtin --rotate right --auto --primary
         xrandr --output $deck.external --off
       }
       external: { ||
         xrandr --output $deck.external --auto --primary
         xrandr --output $deck.builtin --off
       }
       dual: { ||
         xrandr --output $deck.external --auto --primary
         xrandr --output $deck.builtin --rotate right --auto --below $deck.external
       }
    }

    def restart_wm [] {
      awesome-client "awesome.restart()"
    }

    def run_dmenu [opts] {
      $opts | dmenu -i -nb "#1d1f21" -nf "#D3D7CF" -sb "#5294e2" -sf "#2f343f" -fn "11" -p "xrandr profile: "
    }

    match (hostname | str trim) {
      "deck" => {
         let choice = ($deck_actions | columns | str join "\n" | run_dmenu $in)
         let action = ($deck_actions | get -o $choice)
         if $action != null { do $action; restart_wm } else { exit 1 }
      }
      "pale" => {
         let choice = ($pale_actions | columns | str join "\n" | run_dmenu $in)
         let action = ($pale_actions | get -o $choice)
         if $action != null { do $action; restart_wm } else { exit 1 }
      }
      _ => {
        notify-send "xrandr unavailable on this host"
        exit 1
      }
    }
''
