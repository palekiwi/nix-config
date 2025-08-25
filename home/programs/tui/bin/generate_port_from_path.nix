{ pkgs, ... }:

pkgs.writeShellScriptBin "generate_port_from_path" ''
  parent_dir=$(basename "$(dirname "$PWD")")
  current_dir=$(basename "$PWD")
  combined="''${parent_dir}''${current_dir}"
  port=$(echo -n "$combined" | cksum | cut -d' ' -f1)
  echo $((32768 + (port % 32768)))
''
