{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-pwd" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="$PWD"
  fi
  tmux set-buffer -w -- "$dir"
  tmux display-message "copy-pwd: copied '$dir'"
''
