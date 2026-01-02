def run_rofi []: list<string> -> string {
    $in
    | uniq
    | str join "\n"
    | column -s, -t
    | rofi -dmenu -i -theme-str "window { width: 40%; height: 50%; location: center; }" -p "Tmux sessions"
}

def main [
    --opencode
    --tmux
] {
    let tmux_flag = if $tmux { "--tmux" } else { "" }
    let sessions = sesh list --json $tmux_flag | from json

    let options = ($sessions
        | if $opencode { where Name =~ "-opencode$" } else { $in }
        | each { |session|
            let attached_marker = if $session.Attached > 0 { "*" } else { " " }
            $"($session.Score),($session.Name),($session.Src),($session.Path),($attached_marker)"
        }
        | sort-by
            {|item| 0 - ($item | split row "," | get 0 | into float)}
            {|item| $item | split row "," | get 1}
            {|item| $item | split row "," | get 3 }
        | each {|item| $item | split row "," | skip 1 | str join ","}
    )

    let choice = ($options | run_rofi)

    if ($choice | is-empty) {
        exit 1
    }

    let session_name = ($choice | split row " " | get 0)

    if ($choice | str ends-with "*") {
        wmctrl -Fa $session_name
    } else {
        kitty -T $session_name -e sesh connect $session_name
    }
}
