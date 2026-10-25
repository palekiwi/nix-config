# cast DSL for the spike service-container model (pi-focused).
# Targets the container of the current directory; tmux session is `pi`.

# Start the container if needed, then attach or create the pi session.
def "cx pi" [] {
    cast up
    cast exec tmux new-session -A -s pi pi
}

# Attach (or create) the container's review session: one window per
# cue-review run, coloured by @review_state in the statusline.
def "cx reviews" [] {
    cast up
    cast exec tmux new-session -A -s review
}

# Derive a tmux window name from cue-review args: prefer the context
# slug, then the head ref, else "review".
def review-window-name [args: list<string>] {
    mut name = "review"
    for i in 0..(($args | length) - 1) {
        if ($args | get $i) in ["--context" "--head"] and ($i + 1) < ($args | length) {
            $name = ($args | get ($i + 1) | path basename | str replace -a "/" "-")
        }
    }
    $name
}

# Fire a cue-review run in the container's review session (detached).
# The window stays open in bash after the run to read artifacts.
def "cx review" [...args: string] {
    cast up
    if ((cast exec tmux has-session -t review | complete).exit_code != 0) {
        cast exec tmux new-session -d -s review
    }
    let cmd = $"cue-review run ($args | str join ' '); exec bash"
    cast exec tmux new-window -t review -n (review-window-name $args) $cmd
}

# Review GitHub PRs by number or branch in the current directory's
# container: checks the PRs exist, fetches refs, ensures per-PR review
# contexts (review-<branch-slug>), and fires one review window per PR.
def "cx review-pr" [
    ...prs: string
    --manifest: path = ~/.config/cast/nix/cue-review/review-run.json
    --context: string
] {
    cast up
    if ((cast exec tmux has-session -t review | complete).exit_code != 0) {
        cast exec tmux new-session -d -s review
    }
    let args = (if $context != null { [--context $context] } else { [] })
    cast exec cue-review pr ...$prs --manifest ($manifest | path expand) ...$args
}

# Windows of the pi session as a table, with pi state.
def "cx ls" [] {
    let fmt = "#{window_index}\t#{window_name}\t#{@pi_state}\t#{window_active}"
    cast exec --headless tmux list-windows -t pi -F $fmt err> /dev/null
    | lines
    | where $it =~ '^\d+\t'  # drop devshell banner lines on stdout
    | split column "\t" index name state active
    | update index { into int }
    | update active { $in == "1" }
}

# pi windows currently working.
def "cx working" [] {
    cx ls | where state == working
}

# --- Cross-workspace instance view (cast ps) ---
# All running cast instances across workspaces: workspace path,
# instance, uptime. The path is `cast -C`-ready.
def "cx ps" [] {
    cast ps
    | get instances
    | insert instance { $in.name? | default "default" }
    | insert up {
        if $in.started? == null { "-" } else {
            let now = ((date now | into int) / 1_000_000_000)
            let hrs = (($now - $in.started) * 1sec) // 1hr
            if $hrs >= 24 { $"($hrs // 24)d ($hrs mod 24)h" } else if $hrs > 0 { $"($hrs)h" } else {
                $"(((($now - $in.started) * 1sec)) // 1min)min"
            }
        }
    }
    | sort-by workspace instance
    | select workspace instance up
}

def ccs [] {
    cast config show | from json | transpose | explore
}

alias cca = cast config allow
alias ccd = cast config diff
