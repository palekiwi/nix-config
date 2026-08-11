{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_wss_dev" ''
  session="spabreaks/wss/dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n debug
  tmux new-window -t $session -n cast-mcp

  tmux send-keys -t $session:1 'USER_EMAIL=pooh@example.com task dev' C-m
  tmux send-keys -t $session:3 'cast mcp start' C-m

  tmux select-window -t $session:1
''
