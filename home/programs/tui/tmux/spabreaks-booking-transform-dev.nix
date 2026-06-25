{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_booking_transform_dev" ''
  session="booking-transform-dev"

  tmux rename-window -t $session:1 dev

  tmux send-keys -t $session:1 'make dev' C-m

  tmux select-window -t $session:1
''
