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

  # Recursively sync all AGENTS.md files
  echo "Syncing AGENTS.md files from $config_dir..."
  ${pkgs.fd}/bin/fd "AGENTS.md" "$config_dir" -t f | while IFS= read -r agent_file; do
      # Get relative path from config_dir
      relative_path="''${agent_file#$config_dir/}"
      target_dir="$(dirname "$relative_path")"

      # Only sync if target directory already exists
      if [[ -n "$target_dir" && "$target_dir" != "." ]]; then
          if [[ -d "$target_dir" ]]; then
              echo "Copying $agent_file to $relative_path"
              cp "$agent_file" "$relative_path"
          else
              echo "Skipping $agent_file - target directory $target_dir does not exist"
          fi
      else
          echo "Copying $agent_file to AGENTS.md"
          cp "$agent_file" "AGENTS.md"
      fi
  done
''
