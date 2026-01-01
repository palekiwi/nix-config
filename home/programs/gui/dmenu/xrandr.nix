{ pkgs }:

pkgs.writers.writeNuBin "dmenu_xrandr" ''
  let pale_builtin = "eDP-1-1"
  let pale_external = "DP-1-2"
  let pale_tablet = "DP-1-3"

  let options_pale = ["builtin", "external", "dual", "presentation"]
  let options_nuc = ["xasus", "dual", "huion", "tv"]
  let options_deck = ["builtin", "external", "dual", "presentation"]

  let deck_builtin = "eDP-1"
  let deck_external = "DisplayPort-0"

  let nuc_tv = "HDMI-A-0"
  let nuc_asus = "HDMI-A-4"
  let nuc_huion = "DisplayPort-0"

  let dmenu_options = ["-i" "-nb" "#1d1f21" "-nf" "#D3D7CF" "-sb" "#5294e2" "-sf" "#2f343f" "-fn" "11" "-p" "xrandr profile: "]

  def restart_wm [] {
    run-external "awesome-client" "awesome.restart()"
  }

  let host = (hostname | str trim)

  match $host {
    "nuc" => {
      let choice = ($options_nuc | str join "\n" | run-external "dmenu" ...$dmenu_options)
      match $choice {
        "asus" => {
          run-external "xrandr" "--output" $nuc_asus "--auto" "--primary" "--output" $nuc_huion "--off" "--output" $nuc_tv "--off"
          restart_wm
        }
        "huion" => {
          run-external "xrandr" "--output" $nuc_asus "--off" "--output" $nuc_huion "--auto" "--primary" "--output" $nuc_tv "--off"
          restart_wm
        }
        "dual" => {
          run-external "xrandr" "--output" $nuc_asus "--auto" "--primary" "--output" $nuc_huion "--auto" "--below" $nuc_asus "--output" $nuc_tv "--off"
          restart_wm
        }
        "tv" => {
          run-external "xrandr" "--output" $nuc_asus "--off" "--output" $nuc_huion "--off" "--output" $nuc_tv "--mode" "1360x768" "--primary"
          restart_wm
        }
        _ => {
          exit 1
        }
      }
    }
    "deck" => {
      let choice = ($options_deck | str join "\n" | run-external "dmenu" ...$dmenu_options)
      match $choice {
        "external" => {
          run-external "xrandr" "--output" $deck_external "--auto" "--primary"
          run-external "xrandr" "--output" $deck_builtin "--off"
          restart_wm
        }
        "builtin" => {
          run-external "xrandr" "--output" $deck_builtin "--rotate right" "--auto" "--primary"
          run-external "xrandr" "--output" $deck_external "--off"
          restart_wm
        }
        "dual" => {
          run-external "xrandr" "--output" $deck_external "--auto" "--primary"
          run-external "xrandr" "--output" $deck_builtin "--rotate right" "--auto" "--below" $deck_external
          restart_wm
        }
        "presentation" => {
          run-external "xrandr" "--output" $deck_builtin "--auto" "--primary"
          run-external "xrandr" "--output" $deck_external "--auto" "--above" $deck_builtin "--rotate" "normal"
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
          run-external "xrandr" "--output" $pale_builtin "--auto" "--primary"
          run-external "xrandr" "--output" $pale_external "--off"
          run-external "xrandr" "--output" $pale_tablet "--off"
          restart_wm
        }
        "external" => {
          run-external "xrandr" "--output" $pale_external "--auto" "--primary"
          run-external "xrandr" "--output" $pale_builtin "--off"
          run-external "xrandr" "--output" $pale_tablet "--off"
          restart_wm
        }
        # TODO: Commented out due to bug in WM configuration that needs to be addressed first
        # "dual" => {
        #   run-external "xrandr" "--output" $pale_external "--auto" "--primary"
        #   run-external "xrandr" "--output" $pale_tablet "--auto" "--below" $pale_external
        #   restart_wm
        # }
        # "presentation" => {
        #   run-external "xrandr" "--output" $pale_builtin "--auto" "--primary"
        #   run-external "xrandr" "--output" $pale_external "--auto" "--above" $pale_builtin
        #   restart_wm
        # }
        _ => {
          exit 1
        }
      }
    }
    _ => {
      run-external "notify-send" "xrandr unavailable on this host"
      exit 1
    }
  }
''
