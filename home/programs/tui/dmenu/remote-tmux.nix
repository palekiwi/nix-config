{ pkgs }:

pkgs.writers.writeNuBin "dmenu_remote_tmux" ''
  def main [
    --tmux
  ] {
    let launcher_args = ["-dmenu" "-i" "-theme-str" "window { width: 40%; location: center; }" "-p" "Kyomu tmux sessions"]

    let sessions = try {
      if $tmux {
        run-external "ssh" "kyomu" "sesh" "list" "--json" "--tmux" | from json
      } else {
        run-external "ssh" "kyomu" "sesh" "list" "--json" | from json
      }
    } catch {
      print "Error: Could not connect to kyomu or retrieve sessions"
      exit 1
    }

    if ($sessions | is-empty) {
      print "No tmux sessions found on kyomu"
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
    let window_title = $"kyomu:($session_name)"

    # Try to find existing window with this session
    let existing_window = try {
      run-external "wmctrl" "-l" | lines | where ($it | str contains $window_title) | get 0?
    } catch { null }

    if ($existing_window | is-not-empty) {
      # Switch to existing window
      run-external "wmctrl" "-Fa" $window_title
    } else {
      # Launch new terminal with connection to remote session
      run-external "kitty" "-T" $window_title "-e" "ssh" "kyomu" "-t" "sesh" "connect" $session_name
    }
  }
''
