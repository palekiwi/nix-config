def run_rofi []: list<string> -> string {
    $in
    | uniq
    | str join "\n"
    | column -s, -t
    | rofi -dmenu -i -theme-str "window { width: 40%; height: 50%; location: center; }" -p "Tmux sessions"
}

def build_options [opencode: bool, tmux: bool] {
    let tmux_flag = if $tmux { "--tmux" } else { "" }
    let sessions = sesh list --json $tmux_flag | from json

    $sessions
    | if $opencode { where Name =~ "-opencode$" } else { $in }
    | each { |session|
        $"($session.Score),($session.Name),($session.Src),($session.Path)"
    }
    | each {|item| $item | split row "," | skip 1 | str join ","}
}

def main [
    --opencode
    --tmux
] {
    let choice = (build_options $opencode $tmux | run_rofi)

    if ($choice | is-empty) {
        exit 1
    }

    let session_name = ($choice | split row " " | get 0)

    if (wmctrl -l | find $choice | is-empty) {
        kitty -T $session_name -e sesh connect $session_name
    } else {
        wmctrl -Fa $session_name
    }
}
