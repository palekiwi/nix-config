window_name="scratch"

if wmctrl -Fa "$window_name"; then
    exit 0
fi

if ! tmux has-session -t '=scratch' 2>/dev/null; then
    tmux new-session -d -s scratch -c "$HOME" "${SHELL:-/bin/sh}" ||
        tmux has-session -t '=scratch'
fi

exec kitty -T "$window_name" -e tmux attach-session -t '=scratch'
