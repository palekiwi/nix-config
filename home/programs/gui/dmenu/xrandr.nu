const DECK_BUILTIN = "eDP-1"
const DECK_EXTERNAL = "DisplayPort-0"

const PALE_BUILTIN = "eDP-1-1"
const PALE_ULTRAWIDE = "DP-1-2"
const PALE_EXTERNAL = "DP-1-3"

const CONFIG = {
    deck: {
        "builtin": [
            { output: $DECK_BUILTIN, opts: ["--rotate", "right", "--auto", "--primary"] }
            { output: $DECK_EXTERNAL, opts: ["--off"] }
        ]
        "external": [
            { output: $DECK_EXTERNAL, opts: ["--auto", "--primary"] }
            { output: $DECK_BUILTIN, opts: ["--off"] }
        ]
        "dual": [
            { output: $DECK_EXTERNAL, opts: ["--auto", "--primary"] }
            { output: $DECK_BUILTIN, opts: ["--rotate", "right", "--auto", "--below", $DECK_EXTERNAL] }
        ]
    }

    pale: {
        "builtin": [
            { output: $PALE_BUILTIN, opts: ["--auto", "--primary"] }
            { output: $PALE_ULTRAWIDE, opts: ["--off"] }
            { output: $PALE_EXTERNAL, opts: ["--off"] }
        ]
        "ultrawide": [
            { output: $PALE_ULTRAWIDE, opts: ["--auto", "--primary"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_EXTERNAL, opts: ["--off"] }
        ]
        "external": [
            { output: $PALE_ULTRAWIDE, opts: ["--off"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_EXTERNAL, opts: ["--auto", "--primary"] }
        ]
        "ultrawide+builtin": [
            { output: $PALE_BUILTIN, opts: ["--auto", "--primary"] }
            { output: $PALE_ULTRAWIDE, opts: ["--off"] }
            { output: $PALE_EXTERNAL, opts: ["--auto", "--left-of", $PALE_BUILTIN] }
        ]
        "ultrawide+external": [
            { output: $PALE_ULTRAWIDE, opts: ["--auto", "--primary"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_EXTERNAL, opts: ["--auto", "--pos", "760x1440"] }
        ]
    }
}

def apply_profile [profile: list] {
    let args = ($profile | reduce --fold [] { |display, acc|
        $acc | append ["--output", $display.output] | append $display.opts
    })

    let result = (do {
        run-external "xrandr" ...$args
    } | complete)

    if $result.exit_code != 0 {
        error make {
            msg: $"Failed to configure display profile: ($result.stderr)"
        }
    }
}

def restart_wm [] {
    awesome-client "awesome.restart()"
}

def run_dmenu [opts] {
    $opts
    | dmenu -i -nb "#1d1f21" -nf "#D3D7CF" -sb "#5294e2" -sf "#2f343f" -fn "11" -p "xrandr profile: "
}

let host = (hostname | str trim)
let profiles = ($CONFIG | get -o $host)

if $profiles == null {
    notify-send "xrandr unavailable on this host"
    exit 1
}

let choice = ($profiles | columns | str join "\n" | run_dmenu $in)

# Handle user cancellation
if ($choice | is-empty) {
    exit 0
}

# Validate and execute
if $choice in ($profiles | columns) {
    try {
        apply_profile ($profiles | get $choice)
        restart_wm
    } catch { |err|
        notify-send -u critical "Display configuration failed" $err.msg
        exit 1
    }
} else {
    notify-send -u normal "Invalid selection" $"Profile '($choice)' does not exist"
    exit 1
}
