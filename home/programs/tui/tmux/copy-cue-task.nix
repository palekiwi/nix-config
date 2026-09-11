{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-cue-task" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="."
  fi

  context=""

  if command -v cue >/dev/null 2>&1; then
      status_json="$(cue -C "$dir" status --json 2>/dev/null)"
      if [ $? -eq 0 ] && [ -n "$status_json" ]; then
          context="$(echo "$status_json" | ${pkgs.jq}/bin/jq -r '.context // empty' 2>/dev/null)"
      fi
  fi

  if [ -z "$context" ]; then
      tmux display-message "copy-cue-task: no active context in $dir"
      exit 0
  fi

  tmux set-buffer -w -- "$context"
  tmux display-message "copy-cue-task: copied '$context'"
''
