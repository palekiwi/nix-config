{ pkgs, ... }:

pkgs.writeShellScriptBin "sync_opencode_extra_config" ''
  if [[ -z "$1" ]]; then
      echo "Usage: sync_opencode_extra_config <config_dir>"
      exit 1
  fi

  config_dir="$1"
  subdir=".opencode"

  if [[ -d "$config_dir/$subdir" ]]; then
      echo "Syncing opencode extra config from $config_dir/$subdir..."
      mkdir -p .opencode
      rsync -av --delete "$config_dir/$subdir/" ".opencode/"
  else
      echo "Warning: Config directory '$config_dir/$subdir' does not exist"
  fi

  if [[ -f "$config_dir/opencode.json" ]]; then
      echo "Syncing opencode.json from $config_dir/opencode.json..."
      cp "$config_dir/opencode.json" "./"
  fi
''
