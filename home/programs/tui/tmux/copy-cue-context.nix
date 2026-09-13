{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_copy-cue-context" ''
  dir="$1"
  if [ -z "$dir" ]; then
      dir="."
  fi

  if ! command -v cue >/dev/null 2>&1; then
      tmux display-message "copy-cue-context: cue not found in PATH"
      exit 0
  fi

  status_json="$(cue -C "$dir" status --json 2>/dev/null)"
  ret=$?
  if [ $ret -ne 0 ] || [ -z "$status_json" ]; then
      tmux display-message "copy-cue-context: failed to get cue status in $dir"
      exit 0
  fi

  address="$(echo "$status_json" | ${pkgs.jq}/bin/jq -r '
    if (.address | type == "string" and contains("/")) then
      .address
    elif (.scope | type == "string" and length > 0) and (.context | type == "string" and length > 0) then
      "\(.scope)/\(.context)"
    else
      empty
    end
  ' 2>/dev/null)"

  if [ -z "$address" ]; then
      tmux display-message "copy-cue-context: no active context in $dir"
      exit 0
  fi

  tmux set-buffer -w -- "$address"
  tmux display-message "copy-cue-context: copied '$address'"
''
