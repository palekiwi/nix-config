{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" ''
  const DECK_BUILTIN = "eDP-1"
  const DECK_EXTERNAL = "DisplayPort-0"

  const PALE_BUILTIN = "eDP-1-1"
  const PALE_EXTERNAL = "DP-1-2"
  const PALE_TABLET = "DP-1-3"

  let actions = {
    deck: {
      "builtin": { ||
        xrandr --output $DECK_BUILTIN --rotate right --auto --primary
        xrandr --output $DECK_EXTERNAL --off
      }
      "external": { ||
        xrandr --output $DECK_EXTERNAL --auto --primary
        xrandr --output $DECK_BUILTIN --off
      }
      "dual": { ||
        xrandr --output $DECK_EXTERNAL --auto --primary
        xrandr --output $DECK_BUILTIN --rotate right --auto --below $DECK_EXTERNAL
      }
    }

    pale: {
      "builtin": { ||
        xrandr --output $PALE_BUILTIN --auto --primary
        xrandr --output $PALE_EXTERNAL --off
        xrandr --output $PALE_TABLET --off
      }
      "external": { ||
        xrandr --output $PALE_EXTERNAL --auto --primary
        xrandr --output $PALE_BUILTIN --off
        xrandr --output $PALE_TABLET --off
      }
      "dual": { ||
        xrandr --output $PALE_BUILTIN --auto --primary
        xrandr --output $PALE_EXTERNAL --off
        xrandr --output $PALE_TABLET --auto --left-of $PALE_BUILTIN --rotate inverted
      }
      "dual-external": { ||
        xrandr --output $PALE_EXTERNAL --auto --primary
        xrandr --output $PALE_BUILTIN --off
        xrandr --output $PALE_TABLET --auto --pos 760x1440 --rotate inverted
      }
    }
  }

  def restart_wm [] {
    awesome-client "awesome.restart()"
  }

  def run_dmenu [opts] {
    $opts | dmenu -i -nb "#1d1f21" -nf "#D3D7CF" -sb "#5294e2" -sf "#2f343f" -fn "11" -p "xrandr profile: "
  }

  let host = (hostname | str trim)
  let actions = ($actions | get -o $host)

  if $actions == null {
    notify-send "xrandr unavailable on this host"
    exit 1
  } else {
    let choice = ($actions | columns | str join "\n" | run_dmenu $in)

    $actions | get $choice | do $in

    restart_wm
  }
''
