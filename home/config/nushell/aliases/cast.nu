def "cdo" [] {
    let session = $"(tmux display-message -p '#S')-cast"

    tmux new-session -d -c $env.PWD -s $session | ignore
    tmux send-keys -t $session 'cast run opencode' C-m
    kitty --detach -T $session tmux attach -t $session
}
