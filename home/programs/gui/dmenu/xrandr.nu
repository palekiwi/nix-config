const DECK_BUILTIN = "eDP-1"
const DECK_EXTERNAL = "DP-1"

const PALE_BUILTIN = "eDP-1"
const PALE_ULTRAWIDE = "DP-3"
const PALE_HUION = "DP-1-2"
const PALE_VITURE = "DP-1-5"

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
            { output: $PALE_HUION, opts: ["--off"] }
            { output: $PALE_VITURE, opts: ["--off"] }
        ]
        "ultrawide": [
            { output: $PALE_ULTRAWIDE, opts: ["--mode", "3440x1440", "--rate", "59.97", "--pos", "0x0", "--primary"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_HUION, opts: ["--off"] }
            { output: $PALE_VITURE, opts: ["--off"] }
        ]
        "huion": [
            { output: $PALE_ULTRAWIDE, opts: ["--off"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_HUION, opts: ["--auto", "--primary"] }
            { output: $PALE_VITURE, opts: ["--off"] }
        ]
        "builtin+huion": [
            { output: $PALE_BUILTIN, opts: ["--auto", "--primary"] }
            { output: $PALE_ULTRAWIDE, opts: ["--off"] }
            { output: $PALE_HUION, opts: ["--auto", "--mode", "1920x1080", "--below", $PALE_BUILTIN] }
            { output: $PALE_VITURE, opts: ["--off"] }
        ]
        "ultrawide+viture": [
            { output: $PALE_ULTRAWIDE, opts: ["--mode", "3440x1440", "--rate", "59.97", "--pos", "0x0", "--primary"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_HUION, opts: ["--off"] }
            { output: $PALE_VITURE, opts: ["--auto","--below", $PALE_ULTRAWIDE] }
        ]
        "ultrawide+huion": [
            { output: $PALE_ULTRAWIDE, opts: ["--mode", "3440x1440", "--rate", "59.97", "--pos", "0x0", "--primary"] }
            { output: $PALE_BUILTIN, opts: ["--off"] }
            { output: $PALE_HUION, opts: ["--auto", "--pos", "760x1440"] }
            { output: $PALE_VITURE, opts: ["--off"] }
        ]
    }
}

def query_outputs [] {
    let result = (xrandr --query | complete)
    if $result.exit_code != 0 {
        error make { msg: $"Failed to query displays: ($result.stderr)" }
    }
    $result.stdout | lines | parse -r '^(?<output>\S+) (?<state>connected|disconnected)\b'
}

def apply_profile [profile: list, outputs: table] {
    let known = ($outputs | get output)
    for display in $profile {
        if "--off" not-in $display.opts and $display.output not-in $known {
            error make { msg: $"Output '($display.output)' is unavailable" }
        }
    }
    let args = ($profile | where { |display| $display.output in $known } | reduce --fold [] { |display, acc|
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

def restart_otd [] {
    systemctl --user restart opentabletdriver
}

def run_dmenu [opts] {
    $opts
    | dmenu -i -nb "#1d1f21" -nf "#D3D7CF" -sb "#5294e2" -sf "#2f343f" -fn "11" -p "xrandr profile: "
}

def main [--profile: string, --layout-only] {
    let host = (^uname -n | str trim)
    let profiles = ($CONFIG | get -o $host)
    let interactive = ($profile == null)

    try {
        if $profiles == null {
            error make { msg: "xrandr unavailable on this host" }
        }

        let choice = if $interactive {
            $profiles | columns | str join "\n" | run_dmenu $in
        } else {
            $profile
        }
        if ($choice | is-empty) {
            return
        }

        let outputs = (query_outputs)
        let selected = if $choice == "auto" and $host == "pale" {
            if ($outputs | any { |output| $output.output == $PALE_ULTRAWIDE and $output.state == "connected" }) {
                "ultrawide"
            } else {
                "builtin"
            }
        } else {
            $choice
        }
        if $selected not-in ($profiles | columns) {
            error make { msg: $"Profile '($selected)' does not exist" }
        }
        apply_profile ($profiles | get $selected) $outputs
        if not $layout_only {
            restart_wm
            restart_otd
        }
    } catch { |err|
        if $interactive {
            notify-send -u critical "Display configuration failed" $err.msg
        } else {
            print --stderr $err.msg
        }
        exit 1
    }
}
