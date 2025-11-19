{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_spabreaks_dev" ''
  session="spabreaks-dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n debug
  tmux new-window -t $session -n mcp-rspec

  tmux send-keys -t $session:1 'make dev' C-m
  tmux send-keys -t $session:2 'sleep 1; task debug-web' C-m
  tmux send-keys -t $session:3 'mcp-rspec' C-m
  tmux select-window -t $session:1
''
