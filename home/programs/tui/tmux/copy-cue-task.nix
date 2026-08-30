{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-cue-task" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="."
  fi

  slug=""

  if command -v cue >/dev/null 2>&1; then
      status_json="$(cue -C "$dir" status --json 2>/dev/null)"
      if [ $? -eq 0 ] && [ -n "$status_json" ]; then
          is_global="$(echo "$status_json" | ${pkgs.jq}/bin/jq -r '.global // false' 2>/dev/null)"
          if [ "$is_global" != "true" ]; then
              slug="$(echo "$status_json" | ${pkgs.jq}/bin/jq -r '.context // empty' 2>/dev/null)"
          fi
      fi
  fi

  if [ -z "$slug" ]; then
      git_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
      cue_head=""
      if [ -f "$dir/.cue/HEAD" ]; then
          cue_head="$dir/.cue/HEAD"
      elif [ -n "$git_root" ] && [ -f "$git_root/.cue/HEAD" ]; then
          cue_head="$git_root/.cue/HEAD"
      fi

      if [ -n "$cue_head" ]; then
          s="$(cat "$cue_head" 2>/dev/null | tr -d '\r\n')"
          if [ -n "$s" ] && [ "$s" != "master" ]; then
              slug="$s"
          fi
      fi
  fi

  if [ -z "$slug" ]; then
      tmux display-message "copy-cue-task: no active task in $dir"
      exit 0
  fi

  tmux set-buffer -w -- "$slug"
  tmux display-message "copy-cue-task: copied '$slug'"
''
