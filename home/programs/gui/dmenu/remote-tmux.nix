{ pkgs }:

pkgs.writers.writeNuBin "dmenu_remote_tmux" ''
  def main [
    host: string
    --prefix: string
    --tmux
  ] {
    let prefix = ($prefix | default $host)

    let launcher_args = ["-dmenu" "-i" "-theme-str" "window { width: 40%; location: center; }" "-p" $"($prefix) tmux sessions"]

    let sessions = try {
      if $tmux {
        run-external "ssh" $host "sesh" "list" "--json" "--tmux" | from json
      } else {
        run-external "ssh" $host "sesh" "list" "--json" "--tmux" "--config" | from json
      }
    } catch {
      run-external "notify-send" "Remote Tmux" $"Could not retrieve sessions from ($host)"
      exit 1
    }

    if ($sessions | is-empty) {
      run-external "notify-send" "Remote Tmux" $"No sessions found on ($host)"
      exit 1
    }

    let options = ($sessions
      | each { |session|
          let attached_marker = if $session.Attached > 0 { "*" } else { " " }
          $"($session.Name),($session.Src),($session.Path),($attached_marker)"
        }
      | sort-by {|item| $item | split row "," | get 0}
      | sort-by {|item| $item | split row "," | get 2}
      | uniq
      | str join "\n"
      | run-external "column" "-s," "-t")

    let choice = ($options | run-external "rofi" ...$launcher_args)

    if ($choice | is-empty) {
      exit 1
    }

    let session_name = ($choice | split row " " | get 0)
    let window_title = $"($prefix):($session_name)"

    let focused = (do { run-external "wmctrl" "-Fa" $window_title } | complete | get exit_code) == 0
    if not $focused {
      run-external "kitty" "-T" $window_title "-e" "ssh" $host "-t" "sesh" "connect" $session_name
    }
  }
''
