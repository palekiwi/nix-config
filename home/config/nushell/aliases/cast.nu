def "cdo" [] {
    let session = $"(tmux display-message -p '#S')-cast"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'cast run opencode --hostname 0.0.0.0 --port 80' C-m
    kitty --detach -T $session tmux attach -t $session
}

def "cro" [] {
    cast run opencode --hostname 0.0.0.0 --port 80
}

def "cso" [] {
    cast shell opencode
}
