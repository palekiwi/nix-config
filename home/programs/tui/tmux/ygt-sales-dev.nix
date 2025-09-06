{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_ygt_sales_dev" ''
  session="sales-dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n debug

  tmux send-keys -t $session:1 'task dev' C-m

  tmux select-window -t $session:1
''