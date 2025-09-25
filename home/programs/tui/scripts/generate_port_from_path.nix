{ pkgs, ... }:

pkgs.writeShellScriptBin "generate_port_from_path" ''
  # Generate a deterministic port (32768-65535) based on directory path
  # This ensures consistent ports per workspace while avoiding system/privileged ports

  # Use provided path or default to current directory, then canonicalize it
  target_path=$(realpath "''${1:-$PWD}")

  parent_dir=$(basename "$(dirname "$target_path")")
  current_dir=$(basename "$target_path")
  pathHash="''${parent_dir}''${current_dir}"
  port=$(echo -n "$pathHash" | cksum | cut -d' ' -f1)
  echo $((32768 + (port % 32768)))
''
