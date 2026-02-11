def "ocx d" [] {
    let session = $"(tmux display-message -p '#S')-ocx"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'ocx opencode' C-m
    kitty --detach -T $session tmux attach -t $session
}

def "ocx planner" [...args] {
    $env.OPENCODE_CONFIG = "/home/pl/.config/opencode/overlays/planner.json"
    $env.OPENCODE_CONFIG_DIR = "/home/pl/.config/opencode/overlays/planner"

    ocx o ...$args
}
