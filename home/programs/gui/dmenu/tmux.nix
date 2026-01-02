{ pkgs }:

pkgs.writers.writeNuBin "dmenu_tmux" ''
  def main [
    --opencode
    --tmux
  ] {
    let launcher_args = ["-dmenu" "-i" "-theme-str" "window { width: 40%; height: 50%; location: center; }" "-p" "Tmux sessions"]

    let sessions = if $tmux {
      run-external "sesh" "list" "--json" "--tmux" | from json
    } else {
      run-external "sesh" "list" "--json" | from json
    }

    let options = ($sessions
      | if $opencode { where Name =~ "-opencode$" } else { $in }
      | each { |session|
          let attached_marker = if $session.Attached > 0 { "*" } else { " " }
          $"($session.Score),($session.Name),($session.Src),($session.Path),($attached_marker)"
        }
      | sort-by {|item| 0 - ($item | split row "," | get 0 | into float)} {|item| $item | split row "," | get 1} {|item| $item | split row "," | get 3}
      | each {|item| $item | split row "," | skip 1 | str join ","}
      | uniq
      | str join "\n"
      | run-external "column" "-s," "-t")

    let choice = ($options | run-external "rofi" ...$launcher_args)

    if ($choice | is-empty) {
      exit 1
    }

    let session_name = ($choice | split row " " | get 0)

    if ($choice | str ends-with "*") {
      run-external "wmctrl" "-Fa" $session_name
    } else {
      run-external "kitty" "-T" $session_name "-e" "sesh" "connect" $session_name
    }
  }
''
