{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_spabreaks_org" ''
  session="spabreaks/spabreaks-org"

  tmux select-window -t $session:1
''
