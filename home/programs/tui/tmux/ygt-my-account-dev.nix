{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_ygt_my_account_dev" ''
  session="my-account-dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n debug

  tmux send-keys -t $session:1 'make dev' C-m
  tmux send-keys -t $session:2 'sleep 1; make debug-web' C-m

  tmux select-window -t $session:1
''